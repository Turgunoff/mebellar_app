import '../../core/network/woody_api_client.dart';

/// A checkout provider the app can deep-link into.
enum PaymentProvider {
  payme,
  click;

  /// Backend path segment + `provider` value (`/orders/{id}/pay/<slug>`).
  String get slug => name;
}

/// A generated checkout deep-link the app opens with
/// `LaunchMode.externalApplication` so the OS hands off to the Payme / Click
/// app. `amount` is whole so'm, echoed from the backend for display.
class CheckoutLink {
  const CheckoutLink({
    required this.provider,
    required this.checkoutUrl,
    required this.amount,
    this.reference,
  });

  final String provider;
  final String checkoutUrl;
  final int amount;

  /// The merchant account value the provider webhook keys on (the order id for
  /// the checkout flow). Echoed by the backend so the app can persist it as a
  /// pending-payment marker and poll the order's settlement on return.
  final String? reference;

  factory CheckoutLink.fromJson(Map<String, dynamic> json) => CheckoutLink(
    provider: json['provider'] as String? ?? '',
    checkoutUrl: json['checkout_url'] as String? ?? '',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    reference: json['reference'] as String?,
  );
}

/// Woody backend's checkout-link surface. A thin seam over [WoodyApiClient] so
/// the checkout flow depends on the contract (and tests mock it), never the
/// network layer directly. Replaces the removed saved-cards repository — there
/// is no card storage or server-side charge anymore.
abstract class PaymentRepository {
  /// Mint a checkout URL for one of the user's own orders
  /// (`POST /orders/{id}/pay/{provider}`). Throws `ApiError` on 404 (not the
  /// user's order) / 409 (already paid) / 503 (provider unconfigured).
  Future<CheckoutLink> checkoutUrl({
    required String orderId,
    required PaymentProvider provider,
  });
}

class WoodyPaymentRepository implements PaymentRepository {
  WoodyPaymentRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<CheckoutLink> checkoutUrl({
    required String orderId,
    required PaymentProvider provider,
  }) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/orders/$orderId/pay/${provider.slug}',
    );
    return CheckoutLink.fromJson(body);
  }
}
