import '../../../../core/network/woody_api_client.dart';
import '../../../../shared/repositories/payment_repository.dart';

/// One purchasable AR-token bundle (mirrors backend `ArTokenPackage`).
class ArTokenPackage {
  const ArTokenPackage({
    required this.code,
    required this.tokens,
    required this.priceUzs,
  });

  final String code;
  final int tokens;
  final int priceUzs;

  factory ArTokenPackage.fromJson(Map<String, dynamic> json) => ArTokenPackage(
    code: json['code'] as String,
    tokens: (json['tokens'] as num?)?.toInt() ?? 0,
    priceUzs: (json['price_uzs'] as num?)?.toInt() ?? 0,
  );
}

/// The seller's AR-token balance + the purchasable catalog — one call powers the
/// counter label and the top-up sheet (`GET /seller/ar-tokens/balance`).
class ArTokenBalance {
  const ArTokenBalance({
    required this.arCredits,
    required this.packages,
    this.ai3dUsed = 0,
    this.ai3dLimit,
  });

  final int arCredits;
  final List<ArTokenPackage> packages;
  final int ai3dUsed;
  final int? ai3dLimit;

  /// True when this part's request must lock 1 AR token (re-request or bonus
  /// quota exhausted). Mirrors backend `ar_request_should_bill`.
  bool requestNeedsToken({required bool partFreeScanUsed}) {
    if (partFreeScanUsed) return true;
    final limit = ai3dLimit;
    if (limit == null || limit < 0) return false;
    return ai3dUsed >= limit;
  }

  factory ArTokenBalance.fromJson(Map<String, dynamic> json) => ArTokenBalance(
    arCredits: (json['ar_credits'] as num?)?.toInt() ?? 0,
    ai3dUsed: (json['ai_3d_used'] as num?)?.toInt() ?? 0,
    ai3dLimit: (json['ai_3d_limit'] as num?)?.toInt(),
    packages: [
      for (final p
          in (json['packages'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
        ArTokenPackage.fromJson(p),
    ],
  );
}

/// One settled or pending AR-token checkout (`ar_token_purchases`).
class ArTokenPurchase {
  const ArTokenPurchase({
    required this.id,
    required this.packageCode,
    required this.tokens,
    required this.amountUzs,
    required this.provider,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String packageCode;
  final int tokens;
  final int amountUzs;
  final String provider;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled';

  factory ArTokenPurchase.fromJson(Map<String, dynamic> json) =>
      ArTokenPurchase(
        id: json['id'] as String,
        packageCode: json['package_code'] as String,
        tokens: (json['tokens'] as num?)?.toInt() ?? 0,
        amountUzs: (json['amount_uzs'] as num?)?.toInt() ?? 0,
        provider: json['provider'] as String? ?? 'payme',
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

/// Data layer for AR tokenisation. Abstract so the seller UI depends on the
/// contract (and tests mock it), not the REST impl.
abstract class ArTokenRepository {
  Future<ArTokenBalance> balance();

  Future<List<ArTokenPurchase>> purchaseHistory({
    int limit = 30,
    int offset = 0,
  });

  /// Start a top-up: mint a Payme/Click checkout deep-link for the package
  /// (`POST /seller/ar-tokens/buy`). Returns the URL the seller opens to pay
  /// plus the purchase `reference` the webhook keys on — the app persists the
  /// reference as a pending-payment marker and polls the purchase status on
  /// return. Tokens are credited when the provider confirms the payment.
  /// Throws `ApiError` on 404 (unknown package) / 503 (provider unconfigured).
  Future<ArTokenCheckout> buy({
    required String packageCode,
    required PaymentProvider provider,
  });
}

/// The result of an AR-token top-up hand-off: the checkout URL to open and the
/// purchase id (`reference`) the app polls for settlement.
class ArTokenCheckout {
  const ArTokenCheckout({required this.url, required this.reference});

  final String url;
  final String? reference;
}

class WoodyArTokenRepository implements ArTokenRepository {
  WoodyArTokenRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<ArTokenBalance> balance() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/seller/ar-tokens/balance',
    );
    return ArTokenBalance.fromJson(res);
  }

  @override
  Future<List<ArTokenPurchase>> purchaseHistory({
    int limit = 30,
    int offset = 0,
  }) async {
    final res = await _api.get<List<dynamic>>(
      '/seller/ar-tokens/purchases',
      query: {'limit': limit, 'offset': offset},
    );
    return [
      for (final row in res.whereType<Map<String, dynamic>>())
        ArTokenPurchase.fromJson(row),
    ];
  }

  @override
  Future<ArTokenCheckout> buy({
    required String packageCode,
    required PaymentProvider provider,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/seller/ar-tokens/buy',
      body: {'package_code': packageCode, 'provider': provider.slug},
    );
    return ArTokenCheckout(
      url: res['checkout_url'] as String? ?? '',
      reference: res['reference'] as String?,
    );
  }
}
