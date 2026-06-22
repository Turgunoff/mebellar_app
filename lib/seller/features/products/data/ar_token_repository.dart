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

/// Data layer for AR tokenisation. Abstract so the seller UI depends on the
/// contract (and tests mock it), not the REST impl.
abstract class ArTokenRepository {
  Future<ArTokenBalance> balance();

  /// Start a top-up: mint a Payme/Click checkout deep-link for the package and
  /// return the URL the seller opens to pay (`POST /seller/ar-tokens/buy`).
  /// Tokens are credited when the provider confirms the payment (webhook — a
  /// documented follow-up). Throws `ApiError` on 404 (unknown package) / 503
  /// (provider unconfigured).
  Future<String> buy({
    required String packageCode,
    required PaymentProvider provider,
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
  Future<String> buy({
    required String packageCode,
    required PaymentProvider provider,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/seller/ar-tokens/buy',
      body: {'package_code': packageCode, 'provider': provider.slug},
    );
    return res['checkout_url'] as String? ?? '';
  }
}
