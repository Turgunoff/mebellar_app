import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/notifications/cubit/notifications_cubit.dart';
import 'package:woody_app/shared/models/notification_model.dart';
import 'package:woody_app/shared/repositories/notifications_data_source.dart';

class _MockNotificationsRepo extends Mock implements NotificationDataSource {}

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
}
