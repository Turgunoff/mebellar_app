import '../../core/network/woody_api_client.dart';

/// One order per shop group placed at checkout (`POST /orders`). The backend
/// resolves the caller from the JWT and computes the authoritative total, so
/// the client only supplies the line items, delivery address and the
/// installation opt-in. A thin seam over [WoodyApiClient] so the critical
/// checkout flow is testable and stops reaching into the network layer
/// directly.
abstract class CheckoutRepository {
  /// Server-computed invoice preview (`POST /orders/quote`) — subtotal,
  /// delivery fee and the (potential) installation fee for the whole cart.
  /// No order is written.
  Future<CheckoutQuote> quote({
    required List<CheckoutOrderLine> lines,
    required String deliveryAddress,
    required bool wantInstallation,
  });

  /// Places the order for one shop group and returns the new order id.
  Future<String> placeOrder({
    required List<CheckoutOrderLine> lines,
    required String deliveryAddress,
    bool wantInstallation = false,
  });
}

class CheckoutOrderLine {
  const CheckoutOrderLine({required this.productId, required this.quantity});

  final String productId;
  final int quantity;
}

/// Invoice breakdown returned by `POST /orders/quote`. `installationFee` is the
/// *potential* amount (sum over installable items) so the toggle can display it
/// and the total can be recomputed locally without a refetch.
class CheckoutQuote {
  const CheckoutQuote({
    required this.subtotal,
    required this.deliveryFee,
    required this.installationFee,
    required this.installationAvailable,
    required this.grandTotal,
  });

  final double subtotal;
  final double deliveryFee;
  final double installationFee;
  final bool installationAvailable;
  final double grandTotal;

  factory CheckoutQuote.fromJson(Map<String, dynamic> json) => CheckoutQuote(
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
    installationFee: (json['installation_fee'] as num?)?.toDouble() ?? 0,
    installationAvailable: json['installation_available'] as bool? ?? false,
    grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0,
  );
}

class WoodyCheckoutRepository implements CheckoutRepository {
  WoodyCheckoutRepository(this._api);

  final WoodyApiClient _api;

  @override
  Future<CheckoutQuote> quote({
    required List<CheckoutOrderLine> lines,
    required String deliveryAddress,
    required bool wantInstallation,
  }) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/orders/quote',
      body: {
        'items': [
          for (final l in lines)
            {'product_id': l.productId, 'quantity': l.quantity},
        ],
        'delivery_address': deliveryAddress,
        'want_installation': wantInstallation,
      },
    );
    return CheckoutQuote.fromJson(body);
  }

  @override
  Future<String> placeOrder({
    required List<CheckoutOrderLine> lines,
    required String deliveryAddress,
    bool wantInstallation = false,
  }) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/orders',
      body: {
        'items': [
          for (final l in lines)
            {'product_id': l.productId, 'quantity': l.quantity},
        ],
        'delivery_address': deliveryAddress,
        'want_installation': wantInstallation,
      },
    );
    return body['id'] as String;
  }
}
