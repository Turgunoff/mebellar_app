import 'dart:async';

import '../../core/realtime/woody_realtime_service.dart';

/// Customer-side realtime order tracker. Lives in the customer mode scope and
/// is disposed when the user switches to seller.
///
/// Emits coarse connection states so screens can render an "Ulanish kutilmoqda"
/// hint. The per-order status delta stream is exposed through
/// `OrderRepository.watch(orderId)` — this service is a connection supervisor
/// only. Woody's WebSocket is app-managed (started post sign-in by AuthCubit);
/// once the backend publishes `order_status_changed` the subscription below
/// carries live deltas, but until then it's inert.
enum OrderTrackingConnection { idle, connecting, connected, disconnected }

class OrderTrackingService {
  OrderTrackingService(this._realtime);

  final WoodyRealtimeService? _realtime;
  StreamSubscription<RealtimeEvent>? _sub;
  bool _disposed = false;

  final _connectionController =
      StreamController<OrderTrackingConnection>.broadcast();
  OrderTrackingConnection _connection = OrderTrackingConnection.idle;

  bool get isActive => _sub != null;
  bool get isDisposed => _disposed;
  OrderTrackingConnection get connection => _connection;
  Stream<OrderTrackingConnection> get connectionStream =>
      _connectionController.stream;

  void _emitConnection(OrderTrackingConnection next) {
    if (_connection == next) return;
    _connection = next;
    if (!_connectionController.isClosed) _connectionController.add(next);
  }

  void watchOrders(String userId) {
    if (_disposed) {
      throw StateError('OrderTrackingService used after dispose');
    }
    _emitConnection(OrderTrackingConnection.connected);
    _sub = _realtime?.eventsOfType('order_status_changed').listen((_) {});
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
    _emitConnection(OrderTrackingConnection.idle);
    await _connectionController.close();
  }
}
