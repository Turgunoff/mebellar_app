import 'package:dio/dio.dart';

import '../models/app_notification.dart';

abstract class NotificationsRepository {
  Stream<List<AppNotification>> watch();
  List<AppNotification> get current;

  /// One-shot fetch (cold load when the screen opens).
  Future<List<AppNotification>> list();
  int unreadCount({String? mode});
  Stream<int> watchUnread({String? mode});

  Future<void> markRead(String id);
  Future<void> markAllRead({String? mode});
  Future<void> clear();

  /// Pretend a push has arrived. The mock hooks this from the simulator
  /// screen and the recurring timer; the remote stub is a no-op because
  /// real OneSignal pushes hit the device directly.
  Future<AppNotification> simulateIncoming(AppNotification notification);
}

class RemoteNotificationsRepository implements NotificationsRepository {
  RemoteNotificationsRepository(this._dio);
  // ignore: unused_field — Sprint 10 backend wires real endpoints.
  final Dio _dio;

  @override
  Stream<List<AppNotification>> watch() => const Stream.empty();

  @override
  List<AppNotification> get current => const [];

  @override
  Future<List<AppNotification>> list() =>
      throw UnimplementedError('Remote notifications — Sprint 10 backend');

  @override
  int unreadCount({String? mode}) => 0;

  @override
  Stream<int> watchUnread({String? mode}) => const Stream.empty();

  @override
  Future<void> markRead(String id) =>
      throw UnimplementedError('Remote notifications — Sprint 10 backend');

  @override
  Future<void> markAllRead({String? mode}) =>
      throw UnimplementedError('Remote notifications — Sprint 10 backend');

  @override
  Future<void> clear() =>
      throw UnimplementedError('Remote notifications — Sprint 10 backend');

  @override
  Future<AppNotification> simulateIncoming(AppNotification notification) async {
    // No-op for remote: real OneSignal already delivered it to the device.
    return notification;
  }
}
