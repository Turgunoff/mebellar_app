import '../../core/network/woody_api_client.dart';

/// A saved card as the Woody backend stores it — masked number + metadata
/// only. The Payme token lives server-side and never round-trips to the app.
class SavedCard {
  const SavedCard({
    required this.id,
    required this.maskedNumber,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String maskedNumber;
  final bool isActive;
  final DateTime? createdAt;

  factory SavedCard.fromJson(Map<String, dynamic> json) => SavedCard(
    id: json['id'] as String,
    maskedNumber: json['masked_number'] as String? ?? '',
    isActive: json['is_active'] as bool? ?? true,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
  );
}

/// Result of charging an order via `POST /orders/{id}/pay`.
class OrderPayResult {
  const OrderPayResult({required this.paymentStatus, required this.provider});

  final String paymentStatus;
  final String provider;

  factory OrderPayResult.fromJson(Map<String, dynamic> json) => OrderPayResult(
    paymentStatus: json['payment_status'] as String? ?? 'unpaid',
    provider: json['payment_provider'] as String? ?? 'cash',
  );

  bool get isPaid => paymentStatus == 'paid';
}

/// Woody backend's saved-cards surface. A thin seam over [WoodyApiClient] so the
/// payment flow is testable and never reaches the network layer directly.
abstract class PaymentCardsRepository {
  Future<List<SavedCard>> list();

  /// Persist a token the app already tokenised + OTP-verified against Payme.
  Future<SavedCard> add({required String token, required String maskedNumber});

  Future<void> remove(String cardId);

  /// Charge an unpaid order with a saved card.
  Future<OrderPayResult> payOrder({
    required String orderId,
    required String cardId,
  });
}

class WoodyPaymentCardsRepository implements PaymentCardsRepository {
  WoodyPaymentCardsRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<List<SavedCard>> list() async {
    final rows = await _api.get<List<dynamic>>('/customer/payment-cards');
    return [
      for (final row in rows.whereType<Map<String, dynamic>>())
        SavedCard.fromJson(row),
    ];
  }

  @override
  Future<SavedCard> add({
    required String token,
    required String maskedNumber,
  }) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/customer/payment-cards',
      body: {'token': token, 'masked_number': maskedNumber},
    );
    return SavedCard.fromJson(body);
  }

  @override
  Future<void> remove(String cardId) async {
    await _api.delete<dynamic>('/customer/payment-cards/$cardId');
  }

  @override
  Future<OrderPayResult> payOrder({
    required String orderId,
    required String cardId,
  }) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/orders/$orderId/pay',
      body: {'card_id': cardId},
    );
    return OrderPayResult.fromJson(body);
  }
}
