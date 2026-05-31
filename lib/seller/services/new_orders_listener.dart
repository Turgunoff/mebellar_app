import 'dart:async';

import '../../core/realtime/woody_realtime_service.dart';

/// Seller-side realtime listener for incoming orders. Lives in the seller
/// mode scope; cancelled automatically when popping the scope.
///
/// Subscribes to `new_order` events on the app-managed Woody WebSocket. The
/// backend doesn't publish them yet, so this is inert until the realtime
/// publisher lands; `SellerOrdersBloc` meanwhile refreshes via its repository.
class NewOrdersListener {
  NewOrdersListener(this._realtime);

  final WoodyRealtimeService? _realtime;
  StreamSubscription<RealtimeEvent>? _sub;
  bool _disposed = false;

  bool get isActive => _sub != null;
  bool get isDisposed => _disposed;

  void listen(String shopId) {
    if (_disposed) {
      throw StateError('NewOrdersListener used after dispose');
    }
    _sub = _realtime?.eventsOfType('new_order').listen((_) {});
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
  }
}
