import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:mebellar_app/config/app_mode.dart';
import 'package:mebellar_app/core/di/service_locator.dart';
import 'package:mebellar_app/core/storage/hive_boxes.dart';
import 'package:mebellar_app/customer/services/order_tracking_service.dart';
import 'package:mebellar_app/seller/services/new_orders_listener.dart';

/// Validates the Sprint 2 mode-switch invariants:
///   - mode-scope singletons are disposed when the scope is popped
///   - root-scope singletons (Hive boxes) survive every switch
///   - 10 consecutive switches don't leak channels or registrations
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mebellar_modeswitch_');
    Hive.init(tmp.path);
    final sl = GetIt.instance;
    await sl.reset();

    // Mimic initRootScope without going through Supabase (no creds in tests).
    final settings = await Hive.openBox(HiveBoxes.settings);
    final cache = await Hive.openBox(HiveBoxes.cache);
    final pendingRoute = await Hive.openBox(HiveBoxes.pendingRoute);
    sl.registerSingleton<Box>(settings, instanceName: HiveBoxes.settings);
    sl.registerSingleton<Box>(cache, instanceName: HiveBoxes.cache);
    sl.registerSingleton<Box>(
      pendingRoute,
      instanceName: HiveBoxes.pendingRoute,
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('Customer scope registers OrderTrackingService and disposes it on pop',
      () async {
    await initModeScope(AppMode.customer);
    final svc = GetIt.instance<OrderTrackingService>();
    expect(svc.isDisposed, isFalse);

    await GetIt.instance.popScope();
    expect(svc.isDisposed, isTrue);
  });

  test('Seller scope registers NewOrdersListener and disposes it on pop',
      () async {
    await initModeScope(AppMode.seller);
    final svc = GetIt.instance<NewOrdersListener>();
    expect(svc.isDisposed, isFalse);

    await GetIt.instance.popScope();
    expect(svc.isDisposed, isTrue);
  });

  test('Switching modes disposes the prior scope service', () async {
    await initModeScope(AppMode.customer);
    final customerSvc = GetIt.instance<OrderTrackingService>();

    // Manual switch (no BuildContext available in pure test)
    await GetIt.instance.popScope();
    await initModeScope(AppMode.seller);

    expect(customerSvc.isDisposed, isTrue);
    final sellerSvc = GetIt.instance<NewOrdersListener>();
    expect(sellerSvc.isDisposed, isFalse);
    expect(
      () => GetIt.instance<OrderTrackingService>(),
      throwsA(isA<Error>()),
      reason: 'OrderTrackingService should not be reachable in seller scope',
    );
  });

  test('Hive boxes (root scope) survive every mode switch', () async {
    final settings =
        GetIt.instance<Box>(instanceName: HiveBoxes.settings);
    settings.put('marker', 'kept');

    for (var i = 0; i < 10; i++) {
      await initModeScope(i.isEven ? AppMode.customer : AppMode.seller);
      await GetIt.instance.popScope();
    }

    expect(settings.isOpen, isTrue);
    expect(settings.get('marker'), 'kept');
  });

  test('10 consecutive switches dispose every prior service', () async {
    final disposed = <Object>[];

    for (var i = 0; i < 10; i++) {
      final mode = i.isEven ? AppMode.customer : AppMode.seller;
      await initModeScope(mode);

      final svc = mode == AppMode.customer
          ? GetIt.instance<OrderTrackingService>() as Object
          : GetIt.instance<NewOrdersListener>() as Object;

      await GetIt.instance.popScope();

      // After pop, the prior service must be marked disposed
      final isDisposed = svc is OrderTrackingService
          ? svc.isDisposed
          : (svc as NewOrdersListener).isDisposed;
      expect(isDisposed, isTrue, reason: 'iteration $i not disposed');
      disposed.add(svc);
    }

    expect(disposed, hasLength(10));
  });
}
