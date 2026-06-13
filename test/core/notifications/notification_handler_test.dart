import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:woody_app/config/app_mode.dart';
import 'package:woody_app/core/auth/app_mode_cubit.dart';
import 'package:woody_app/core/notifications/notification_handler.dart';

/// In-memory [Box] stand-in. Hive's real disk-write futures never settle in a
/// `testWidgets` fake-async zone (they hang teardown), so both the pending-
/// route box and [AppModeCubit]'s settings box use this: `put`/`delete` mutate
/// the map synchronously (the `async` body has no await before the write), so
/// `get` reads back immediately and the cubit's `emit` lands within a pumped
/// frame.
class _FakeBox extends Fake implements Box<dynamic> {
  final Map<dynamic, dynamic> _m = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) => _m[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _m[key] = value;

  @override
  Future<void> delete(dynamic key) async => _m.remove(key);
}

/// Cross-mode push routing invariants (QA: a notification for the *other*
/// mode must switch modes and survive the Phoenix rebirth, not get dropped).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBox pendingBox;

  setUp(() {
    pendingBox = _FakeBox();
  });

  tearDown(() => GetIt.instance.reset());

  NotificationHandler handler() => NotificationHandler(pendingBox);

  AppModeCubit registerModeCubit() {
    final cubit = AppModeCubit(_FakeBox());
    GetIt.instance.registerSingleton<AppModeCubit>(cubit);
    addTearDown(cubit.close);
    return cubit;
  }

  test('consumeFor returns the route + kind for the matching mode, then clears',
      () {
    final h = handler();
    h.savePendingRoute('/orders/1', AppMode.customer.name, kind: 'order_created');

    final got = h.consumeFor(AppMode.customer.name);
    expect(got?.route, '/orders/1');
    expect(got?.kind, 'order_created');

    // Consumed once — a second read finds nothing.
    expect(h.consumeFor(AppMode.customer.name), isNull);
    expect(pendingBox.get('pending_route'), isNull);
  });

  test('consumeFor for the WRONG mode leaves the route for the target shell',
      () {
    final h = handler();
    h.savePendingRoute(
      '/seller/orders/9',
      AppMode.seller.name,
      kind: 'seller_new_order',
    );

    // The outgoing customer shell's resume-consume must NOT wipe a route meant
    // for seller (this is the race that previously dropped cross-mode pushes).
    expect(h.consumeFor(AppMode.customer.name), isNull);
    expect(pendingBox.get('pending_route'), '/seller/orders/9');

    // The seller shell (mounted after the Phoenix rebirth) still gets it.
    final got = h.consumeFor(AppMode.seller.name);
    expect(got?.route, '/seller/orders/9');
    expect(pendingBox.get('pending_route'), isNull);
  });

  test('consumeFor drops AND clears a stale (>5 min) route', () {
    pendingBox.put('pending_route', '/orders/1');
    pendingBox.put('pending_mode', AppMode.customer.name);
    pendingBox.put(
      'pending_ts',
      DateTime.now().subtract(const Duration(minutes: 6)).toIso8601String(),
    );

    final h = handler();
    expect(h.consumeFor(AppMode.customer.name), isNull);
    // Expired entries are GC'd even for the matching mode.
    expect(pendingBox.get('pending_route'), isNull);
  });

  testWidgets('routeFromPush stashes without switching when target == current',
      (tester) async {
    final cubit = registerModeCubit();
    final h = handler();
    await tester.pumpWidget(const SizedBox.shrink());

    h.routeFromPush(
      route: '/orders/1',
      mode: AppMode.customer.name,
      kind: 'order_created',
    );

    // No switch is even scheduled — pumping a frame leaves the mode untouched.
    await tester.pump();
    expect(cubit.state, AppMode.customer);
    expect(h.consumeFor(AppMode.customer.name)?.route, '/orders/1');
  });

  testWidgets('routeFromPush requests a mode switch when target != current',
      (tester) async {
    final cubit = registerModeCubit();
    final h = handler();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(cubit.state, AppMode.customer);

    h.routeFromPush(
      route: '/seller/orders/9',
      mode: AppMode.seller.name,
      kind: 'seller_new_order',
    );

    // Route is stashed synchronously, keyed to the target (seller) mode so the
    // seller shell — brought up by the switch + Phoenix rebirth — gets it.
    expect(pendingBox.get('pending_route'), '/seller/orders/9');
    expect(pendingBox.get('pending_mode'), AppMode.seller.name);
    // The switch is deferred to a post-frame callback (so a cold-start emit
    // can't beat runApp mounting the root listener) — still customer here.
    expect(cubit.state, AppMode.customer);

    // First pump fires the post-frame callback → switchMode() (which awaits an
    // async box write before emitting); the second drains that microtask so
    // the emit is observable.
    await tester.pump();
    await tester.pump();
    expect(cubit.state, AppMode.seller);
  });
}
