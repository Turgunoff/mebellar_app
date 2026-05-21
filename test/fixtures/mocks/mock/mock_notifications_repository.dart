import 'dart:async';

import 'package:woody_app/shared/models/app_notification.dart';
import 'package:woody_app/shared/repositories/notifications_repository.dart';
import 'mock_notifications_data.dart';

/// In-memory feed driven by both the simulator screen and a recurring timer.
/// The repository is the single source of truth for the unread badge — both
/// the customer and seller bottom-nav badges subscribe to `watchUnread()`
/// with their respective `mode` filter so the count stays accurate after a
/// scope switch.
class MockNotificationsRepository implements NotificationsRepository {
  MockNotificationsRepository() {
    _items.addAll(MockNotificationsData.seed());
    // Simulate a fresh inbound notification every ~45 seconds so the unread
    // badge animation has something to react to during demos.
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_items.isEmpty) return;
      _injectNext();
    });
    _emit();
  }

  static const _delay = Duration(milliseconds: 200);

  final List<AppNotification> _items = [];
  final _itemsController = StreamController<List<AppNotification>>.broadcast();
  final _unreadController = StreamController<int>.broadcast();
  Timer? _timer;
  int _rotation = 0;

  void _emit() {
    final snapshot = List<AppNotification>.unmodifiable(_items);
    _itemsController.add(snapshot);
    _unreadController.add(_items.where((n) => !n.read).length);
  }

  @override
  Stream<List<AppNotification>> watch() => _itemsController.stream;

  @override
  List<AppNotification> get current =>
      List<AppNotification>.unmodifiable(_items);

  @override
  Future<List<AppNotification>> list() async {
    await Future<void>.delayed(_delay);
    return current;
  }

  @override
  int unreadCount({String? mode}) {
    return _items
        .where((n) =>
            !n.read && (mode == null || n.kind.mode == mode))
        .length;
  }

  @override
  Stream<int> watchUnread({String? mode}) {
    if (mode == null) return _unreadController.stream;
    // Re-derive a per-mode stream so customer/seller badges only count
    // notifications addressed to *their* mode.
    return _itemsController.stream.map(
      (list) => list
          .where((n) => !n.read && n.kind.mode == mode)
          .length,
    );
  }

  @override
  Future<void> markRead(String id) async {
    await Future<void>.delayed(_delay);
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0 || _items[idx].read) return;
    _items[idx] = _items[idx].copyWith(read: true);
    _emit();
  }

  @override
  Future<void> markAllRead({String? mode}) async {
    await Future<void>.delayed(_delay);
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].read) continue;
      if (mode != null && _items[i].kind.mode != mode) continue;
      _items[i] = _items[i].copyWith(read: true);
      changed = true;
    }
    if (changed) _emit();
  }

  @override
  Future<void> clear() async {
    await Future<void>.delayed(_delay);
    _items.clear();
    _emit();
  }

  @override
  Future<AppNotification> simulateIncoming(AppNotification notification) async {
    _items.insert(0, notification);
    _emit();
    return notification;
  }

  /// Round-robin between a few templates so the timer doesn't repeatedly
  /// inject the same template back-to-back.
  void _injectNext() {
    _rotation = (_rotation + 1) % 4;
    final next = switch (_rotation) {
      0 => MockNotificationsData.newOrderTemplate(),
      1 => MockNotificationsData.orderDeliveredTemplate(),
      2 => MockNotificationsData.productApprovedTemplate(),
      _ => MockNotificationsData.promoTemplate(),
    };
    _items.insert(0, next);
    _emit();
  }

  Future<void> dispose() async {
    _timer?.cancel();
    if (!_itemsController.isClosed) await _itemsController.close();
    if (!_unreadController.isClosed) await _unreadController.close();
  }
}
