import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Customer-side realtime order tracker. Lives in the customer mode scope and
/// is disposed (channel unsubscribed) when the user switches to seller.
///
/// Sprint 5: emits coarse connection states (`connecting / connected /
/// disconnected`) so screens can render an "Ulanish kutilmoqda" hint when
/// the websocket flakes. The actual per-order status delta stream is exposed
/// through `OrderRepository.watch(orderId)` — this service is a connection
/// supervisor only.
enum OrderTrackingConnection { idle, connecting, connected, disconnected }

class OrderTrackingService {
  OrderTrackingService(this._client);

  final SupabaseClient? _client;
  RealtimeChannel? _channel;
  bool _disposed = false;

  final _connectionController =
      StreamController<OrderTrackingConnection>.broadcast();
  OrderTrackingConnection _connection = OrderTrackingConnection.idle;

  bool get isActive => _channel != null;
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
    final client = _client;
    if (client == null) {
      // Dev: no Supabase configured; mock repository drives status changes.
      _emitConnection(OrderTrackingConnection.connected);
      return;
    }
    _emitConnection(OrderTrackingConnection.connecting);
    _channel = client
        .channel('public:orders:user_id=eq.$userId')
        .subscribe((status, [_]) {
      if (_disposed) return;
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _emitConnection(OrderTrackingConnection.connected);
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.closed:
          _emitConnection(OrderTrackingConnection.disconnected);
      }
    });
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      await ch.unsubscribe();
    }
    _emitConnection(OrderTrackingConnection.idle);
    await _connectionController.close();
  }
}
