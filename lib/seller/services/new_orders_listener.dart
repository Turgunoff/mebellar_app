import 'package:supabase_flutter/supabase_flutter.dart';

/// Seller-side realtime listener for incoming orders. Lives in the seller
/// mode scope; unsubscribed automatically when popping the scope.
///
/// Sprint 8 wires this into `SellerOrdersBloc`. Sprint 2 keeps the stub so
/// the dispose path is exercised.
class NewOrdersListener {
  NewOrdersListener(this._client);

  final SupabaseClient? _client;
  RealtimeChannel? _channel;
  bool _disposed = false;

  bool get isActive => _channel != null;
  bool get isDisposed => _disposed;

  void listen(String shopId) {
    if (_disposed) {
      throw StateError('NewOrdersListener used after dispose');
    }
    final client = _client;
    if (client == null) return;
    _channel = client
        .channel('public:orders:shop_id=eq.$shopId')
        .subscribe();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      await ch.unsubscribe();
    }
  }
}
