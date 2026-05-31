
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
