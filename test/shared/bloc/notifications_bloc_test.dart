import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:woody_app/config/app_mode.dart';
import 'package:woody_app/core/notifications/notification_handler.dart';
import 'package:woody_app/shared/bloc/notifications_bloc.dart';
import 'package:woody_app/shared/mock/mock_notifications_data.dart';
import 'package:woody_app/shared/mock/mock_notifications_repository.dart';
import 'package:woody_app/shared/models/app_notification.dart';

void main() {
  setUpAll(() {
    Hive.init('./test/.hive');
  });

  group('NotificationsBloc (mock repository)', () {
    blocTest<NotificationsBloc, NotificationsState>(
      'fetch -> 5 seeded notifications',
      build: () => NotificationsBloc(MockNotificationsRepository()),
      act: (bloc) => bloc.add(const NotificationsRequested()),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(bloc.state.status, NotificationsStatus.ready);
        expect(bloc.state.items.length, 5);
        // Two unread in the seed (notif-1 customer + notif-2 seller).
        expect(bloc.state.unread, 2);
      },
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'unreadFor filters by mode (customer vs seller counts differ)',
      build: () => NotificationsBloc(MockNotificationsRepository()),
      act: (bloc) => bloc.add(const NotificationsRequested()),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(bloc.state.unreadFor('customer'), 1);
        expect(bloc.state.unreadFor('seller'), 1);
      },
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'mark as read flips the flag and decrements the count',
      build: () => NotificationsBloc(MockNotificationsRepository()),
      act: (bloc) async {
        bloc.add(const NotificationsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 400));
        bloc.add(const NotificationRead('notif-1'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      verify: (bloc) {
        final n = bloc.state.items.firstWhere((x) => x.id == 'notif-1');
        expect(n.read, isTrue);
        expect(bloc.state.unread, 1);
      },
    );

    test('simulator injection appends new unread item', () async {
      final repo = MockNotificationsRepository();
      final bloc = NotificationsBloc(repo);
      bloc.add(const NotificationsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await repo.simulateIncoming(MockNotificationsData.newOrderTemplate());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.items.length, 6);
      expect(bloc.state.items.first.read, isFalse);
      await bloc.close();
      await repo.dispose();
    });
  });

  group('NotificationHandler', () {
    late Box box;

    setUp(() async {
      box = await Hive.openBox(
          'test_pending_${DateTime.now().millisecondsSinceEpoch}');
    });

    tearDown(() async {
      await box.clear();
      await box.close();
    });

    test('savePendingRoute + consume returns route once for matching mode',
        () {
      final h = NotificationHandler(box);
      h.savePendingRoute('/orders/abc', AppMode.customer.name);
      expect(h.consumeFor(AppMode.customer.name), '/orders/abc');
      // Second call drains to null since the consume cleared the stash.
      expect(h.consumeFor(AppMode.customer.name), isNull);
    });

    test('consume from a different mode discards (returns null)', () {
      final h = NotificationHandler(box);
      h.savePendingRoute('/orders/abc', AppMode.seller.name);
      expect(h.consumeFor(AppMode.customer.name), isNull);
    });

    test('stale routes (>5 min) are discarded', () {
      final h = NotificationHandler(box);
      // Inject a stash with an artificially-old timestamp.
      box.put('pending_route', '/old');
      box.put('pending_mode', AppMode.customer.name);
      box.put('pending_ts',
          DateTime.now().subtract(const Duration(minutes: 6)).toIso8601String());
      expect(h.consumeFor(AppMode.customer.name), isNull);
    });

    test('peek does not drain the saved value', () {
      final h = NotificationHandler(box);
      h.savePendingRoute('/cart', AppMode.customer.name);
      expect(h.peek()?.route, '/cart');
      expect(h.peek()?.mode, 'customer');
      // Still consumable after peek.
      expect(h.consumeFor(AppMode.customer.name), '/cart');
    });
  });

  group('AppNotification payload roundtrip', () {
    test('toPayload + fromPayload survives the trip', () {
      final original = AppNotification(
        id: 'notif-test',
        kind: NotificationKind.orderPlaced,
        title: 'T',
        body: 'B',
        route: '/orders/x',
        createdAt: DateTime.parse('2026-05-03T10:00:00Z'),
      );
      final restored = AppNotification.fromPayload(original.toPayload());
      expect(restored.id, original.id);
      expect(restored.kind, original.kind);
      expect(restored.route, original.route);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
