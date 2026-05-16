import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/notifications/cubit/notifications_cubit.dart';
import 'package:woody_app/shared/models/notification_model.dart';
import 'package:woody_app/shared/repositories/supabase_notifications_repository.dart';

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
}
