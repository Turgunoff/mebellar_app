import '../../../../core/network/woody_api_client.dart';

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
  const ArTokenBalance({required this.arCredits, required this.packages});

  final int arCredits;
  final List<ArTokenPackage> packages;

  factory ArTokenBalance.fromJson(Map<String, dynamic> json) => ArTokenBalance(
    arCredits: (json['ar_credits'] as num?)?.toInt() ?? 0,
    packages: [
      for (final p in (json['packages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>())
        ArTokenPackage.fromJson(p),
    ],
  );
}

/// Result of a successful token purchase (`POST /seller/ar-tokens/buy`).
class ArTokenPurchaseResult {
  const ArTokenPurchaseResult({
    required this.tokensAdded,
    required this.balance,
    required this.paymentId,
  });

  final int tokensAdded;
  final int balance;
  final String paymentId;

  factory ArTokenPurchaseResult.fromJson(Map<String, dynamic> json) =>
      ArTokenPurchaseResult(
        tokensAdded: (json['tokens_added'] as num?)?.toInt() ?? 0,
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        paymentId: json['payment_id'] as String? ?? '',
      );
}

/// Data layer for AR tokenisation. Abstract so the seller UI depends on the
/// contract (and tests mock it), not the REST impl.
abstract class ArTokenRepository {
  Future<ArTokenBalance> balance();

  /// Buy a package with a saved Payme card. The backend charges the card and
  /// credits the tokens in one transaction; throws [ApiError] on a payment
  /// failure (402) / unknown package (404) / unverified card.
  Future<ArTokenPurchaseResult> buy({
    required String packageCode,
    required String cardId,
  });
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
  Future<ArTokenPurchaseResult> buy({
    required String packageCode,
    required String cardId,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/seller/ar-tokens/buy',
      body: {'package_code': packageCode, 'card_id': cardId},
    );
    return ArTokenPurchaseResult.fromJson(res);
  }
}
