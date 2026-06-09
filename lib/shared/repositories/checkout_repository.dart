import '../../core/network/woody_api_client.dart';

/// One order per shop group placed at checkout (`POST /orders`). The backend
/// resolves the caller from the JWT and computes the authoritative total, so
/// the client only supplies the line items + delivery address. A thin seam
/// over [WoodyApiClient] so the critical checkout flow is testable and stops
/// reaching into the network layer directly.
abstract class CheckoutRepository {
  /// Places the order for one shop group and returns the new order id.
  Future<String> placeOrder({
    required List<CheckoutOrderLine> lines,
    required String deliveryAddress,
  });
}

class CheckoutOrderLine {
  const CheckoutOrderLine({required this.productId, required this.quantity});

  final String productId;
  final int quantity;
}

class WoodyCheckoutRepository implements CheckoutRepository {
  WoodyCheckoutRepository(this._api);

  final WoodyApiClient _api;

  @override
  Future<String> placeOrder({
    required List<CheckoutOrderLine> lines,
    required String deliveryAddress,
  }) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/orders',
      body: {
        'items': [
          for (final l in lines)
            {'product_id': l.productId, 'quantity': l.quantity},
        ],
        'delivery_address': deliveryAddress,
      },
    );
    return body['id'] as String;
  }
}
