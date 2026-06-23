import '../../core/network/woody_api_client.dart';
import 'pending_payment.dart';

/// Resolves whether a pending external payment has settled. Abstract so the
/// recovery flow depends on the contract (and tests fake it), never the network
/// layer directly. Routes per [PendingPaymentKind] to that kind's status
/// endpoint.
abstract class PaymentStatusGateway {
  Future<PaymentOutcome> check(PendingPayment payment);
}

class WoodyPaymentStatusGateway implements PaymentStatusGateway {
  WoodyPaymentStatusGateway({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<PaymentOutcome> check(PendingPayment payment) async {
    try {
      switch (payment.kind) {
        case PendingPaymentKind.order:
          final body = await _api.get<Map<String, dynamic>>(
            '/orders/${payment.reference}',
          );
          // Only a settled `paid` counts. `unpaid` (and anything else) stays
          // pending — the webhook may simply not have landed yet.
          return body['payment_status'] == 'paid'
              ? PaymentOutcome.paid
              : PaymentOutcome.pending;
        case PendingPaymentKind.arTokens:
          // `await` (not bare return) so a thrown ApiError is caught below
          // rather than escaping as a rejected future.
          return await _checkPaidFlag(
            '/seller/ar-tokens/purchases/${payment.reference}',
          );
        case PendingPaymentKind.subscription:
          return await _checkPaidFlag(
            '/seller/tariff/receipts/${payment.reference}/status',
          );
      }
    } catch (_) {
      // Network down, token expired, or a 404 — we can't tell. The caller
      // treats `unknown` like `pending` (never claims success) and, after the
      // poll window, falls back to "track it in your orders".
      return PaymentOutcome.unknown;
    }
  }

  /// AR-token + subscription status endpoints share a `{status, paid}` shape;
  /// the backend has already normalized each kind's settled sentinel into
  /// `paid`, so the app reads one boolean.
  Future<PaymentOutcome> _checkPaidFlag(String path) async {
    final body = await _api.get<Map<String, dynamic>>(path);
    return (body['paid'] as bool? ?? false)
        ? PaymentOutcome.paid
        : PaymentOutcome.pending;
  }
}
