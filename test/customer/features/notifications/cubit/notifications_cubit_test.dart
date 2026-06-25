import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/auth/auth_repository.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/customer/features/notifications/cubit/notifications_cubit.dart';
import 'package:woody_app/shared/models/notification_model.dart';
import 'package:woody_app/shared/repositories/notifications_data_source.dart';

class _MockNotificationsRepo extends Mock implements NotificationDataSource {}

class _MockAuth extends Mock implements AuthRepository {}

NotificationModel _notif(String id, {bool isRead = false}) => NotificationModel(
      id: id,
      userId: 'user-1',
      title: 'Title $id',
      body: 'Body $id',
      kind: NotificationKind.general,
      referenceId: null,
      isRead: isRead,
      createdAt: DateTime.utc(2026, 5, 16),
    );

// Seller-surface row (resolveTargetMode() == AppMode.seller) — must be kept
// out of the customer inbox/bell and counted on the profile's seller badge.
NotificationModel _sellerNotif(String id, {bool isRead = false}) =>
    NotificationModel(
      id: id,
      userId: 'user-1',
      title: 'Seller $id',
      body: 'Body $id',
      kind: NotificationKind.sellerNewOrder,
      referenceId: null,
      isRead: isRead,
      createdAt: DateTime.utc(2026, 5, 16),
    );

void main() {
  late _MockNotificationsRepo repo;

  setUp(() => repo = _MockNotificationsRepo());

  blocTest<NotificationsCubit, NotificationsState>(
    'load emits [loading, ready] with the fetched notifications',
    build: () {
      when(repo.list)
          .thenAnswer((_) async => [_notif('n1'), _notif('n2')]);
      return NotificationsCubit(repo);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      isA<NotificationsState>()
          .having((s) => s.status, 'status', NotificationsStatus.loading),
      isA<NotificationsState>()
          .having((s) => s.status, 'status', NotificationsStatus.ready)
          .having((s) => s.items.length, 'items', 2),
    ],
  );

  blocTest<NotificationsCubit, NotificationsState>(
    'load emits [loading, failure] when the repository throws',
    build: () {
      when(repo.list).thenThrow(Exception('inbox unreachable'));
      return NotificationsCubit(repo);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      isA<NotificationsState>()
          .having((s) => s.status, 'status', NotificationsStatus.loading),
      isA<NotificationsState>()
          .having((s) => s.status, 'status', NotificationsStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<NotificationsCubit, NotificationsState>(
    'markRead optimistically flips the item and persists the change',
    build: () {
      when(() => repo.markRead(any())).thenAnswer((_) async {});
      return NotificationsCubit(repo);
    },
    seed: () => NotificationsState(
      status: NotificationsStatus.ready,
      items: [_notif('n1', isRead: false)],
    ),
    act: (cubit) => cubit.markRead('n1'),
    expect: () => [
      isA<NotificationsState>()
          .having((s) => s.items.single.isRead, 'isRead', true)
          .having((s) => s.unreadCount, 'unreadCount', 0),
    ],
    verify: (_) => verify(() => repo.markRead('n1')).called(1),
  );

  blocTest<NotificationsCubit, NotificationsState>(
    'markRead is a no-op for an already-read notification',
    build: () => NotificationsCubit(repo),
    seed: () => NotificationsState(
      status: NotificationsStatus.ready,
      items: [_notif('n1', isRead: true)],
    ),
    act: (cubit) => cubit.markRead('n1'),
    expect: () => const <NotificationsState>[],
    verify: (_) => verifyNever(() => repo.markRead(any())),
  );

  test('audience getters split customer vs seller rows', () {
    final state = NotificationsState(
      status: NotificationsStatus.ready,
      items: [
        _notif('c1'), // customer, unread
        _notif('c2', isRead: true), // customer, read
        _sellerNotif('s1'), // seller, unread
        _sellerNotif('s2'), // seller, unread
      ],
    );
    // Customer surface excludes the seller rows entirely (the leak fix).
    expect(state.customerItems.map((n) => n.id).toList(), ['c1', 'c2']);
    expect(state.customerUnreadCount, 1);
    expect(state.sellerUnreadCount, 2);
    expect(state.unreadCount, 3);
  });

  blocTest<NotificationsCubit, NotificationsState>(
    'markAllRead() clears only customer rows and scopes the backend call',
    build: () {
      when(() => repo.markAllRead(mode: any(named: 'mode')))
          .thenAnswer((_) async {});
      return NotificationsCubit(repo);
    },
    seed: () => NotificationsState(
      status: NotificationsStatus.ready,
      items: [_notif('c1'), _sellerNotif('s1')],
    ),
    act: (cubit) => cubit.markAllRead(),
    expect: () => [
      isA<NotificationsState>()
          .having((s) => s.customerUnreadCount, 'customerUnread', 0)
          .having((s) => s.sellerUnreadCount, 'sellerUnread', 1),
    ],
    verify: (_) => verify(() => repo.markAllRead(mode: 'customer')).called(1),
  );

  blocTest<NotificationsCubit, NotificationsState>(
    'markAllRead(seller) clears only seller rows and scopes the backend call',
    build: () {
      when(() => repo.markAllRead(mode: any(named: 'mode')))
          .thenAnswer((_) async {});
      return NotificationsCubit(repo);
    },
    seed: () => NotificationsState(
      status: NotificationsStatus.ready,
      items: [_notif('c1'), _sellerNotif('s1')],
    ),
    act: (cubit) => cubit.markAllRead(mode: 'seller'),
    expect: () => [
      isA<NotificationsState>()
          .having((s) => s.customerUnreadCount, 'customerUnread', 1)
          .having((s) => s.sellerUnreadCount, 'sellerUnread', 0),
    ],
    verify: (_) => verify(() => repo.markAllRead(mode: 'seller')).called(1),
  );

  group('auth gating', () {
    late _MockAuth auth;
    late StreamController<TokenPair?> authChanges;

    setUp(() {
      auth = _MockAuth();
      authChanges = StreamController<TokenPair?>.broadcast();
      when(() => auth.authStateChanges).thenAnswer((_) => authChanges.stream);
    });

    tearDown(() => authChanges.close());

    // Regression for the guest /notifications 401 loop: when signed out the
    // cubit must NOT fire `GET /notifications` (it 401s for guests). The screen
    // rests on public news; the personal call is skipped, not failed.
    test('guest load() does not hit the personal /notifications endpoint',
        () async {
      when(() => auth.isAuthenticated).thenReturn(false);
      final cubit = NotificationsCubit(repo, auth: auth);

      await cubit.load();

      verifyNever(repo.list);
      expect(cubit.state.status, NotificationsStatus.ready);
      await cubit.close();
    });

    test('authed load() does fetch the personal endpoint', () async {
      when(() => auth.isAuthenticated).thenReturn(true);
      when(repo.list).thenAnswer((_) async => [_notif('n1')]);
      final cubit = NotificationsCubit(repo, auth: auth);

      await cubit.load();

      verify(repo.list).called(1);
      expect(cubit.state.items.single.id, 'n1');
      await cubit.close();
    });

    // The token store emits on a silent refresh (authed → authed) and, for a
    // guest, on a no-op clear. Reloading on those re-fired the personal fetch
    // for nothing (and drove the loop). Only a genuine signed-in ↔ signed-out
    // flip should reload.
    test('reloads on a real auth flip but not on a token-refresh re-emit',
        () async {
      var authed = false;
      when(() => auth.isAuthenticated).thenAnswer((_) => authed);
      when(repo.list).thenAnswer((_) async => [_notif('n1')]);
      final cubit = NotificationsCubit(repo, auth: auth);

      authed = true;
      authChanges.add(const TokenPair(accessToken: 'a', refreshToken: 'r'));
      await pumpEventQueue();
      // A silent refresh rotates the pair (authed → authed): must NOT reload.
      authChanges.add(const TokenPair(accessToken: 'a2', refreshToken: 'r2'));
      await pumpEventQueue();

      verify(repo.list).called(1);
      await cubit.close();
    });
  });
}
