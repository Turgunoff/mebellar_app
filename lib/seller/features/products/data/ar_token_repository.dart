import 'dart:io';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/network/woody_api_client.dart';
import '../../../../core/storage/r2_upload_client.dart';
import '../../../../shared/repositories/payment_repository.dart';
import '../../../../shared/repositories/tariff_repository.dart';

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
    this.pendingPurchase,
  });

  final int arCredits;
  final List<ArTokenPackage> packages;
  final int ai3dUsed;
  final int? ai3dLimit;
  final ArTokenPurchase? pendingPurchase;

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
    pendingPurchase: json['pending_purchase'] is Map<String, dynamic>
        ? ArTokenPurchase.fromJson(
            json['pending_purchase'] as Map<String, dynamic>,
          )
        : null,
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
  bool get isPendingReview => status == 'pending_review';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
  bool get canCancel => isPending || isPendingReview;

  bool get isResolved => isPaid || isRejected || isCancelled;

  /// 24-hour SLA for manual (P2P) purchases awaiting admin review.
  Duration get slaRemaining {
    final due = createdAt.add(const Duration(hours: 24));
    final left = due.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

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

  /// Abandon a pending checkout the seller opened but didn't pay.
  Future<void> cancelPurchase(String purchaseId);

  /// Platform receiving card for P2P top-ups (`GET /seller/ar-tokens/payment-instructions`).
  Future<TariffPaymentInstructions> paymentInstructions();

  /// Upload a payment receipt screenshot to R2 (`payment-receipts` bucket).
  Future<String> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  });

  /// Submit a manual card transfer + receipt (`POST /seller/ar-tokens/purchases/manual`).
  Future<ArTokenPurchase> submitManualPurchase({
    required String packageCode,
    required String paymentScreenshotPath,
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
  WoodyArTokenRepository({
    required WoodyApiClient api,
    required AuthRepository auth,
    required R2UploadClient uploads,
  }) : _api = api,
       _auth = auth,
       _uploads = uploads;

  final WoodyApiClient _api;
  final AuthRepository _auth;
  final R2UploadClient _uploads;

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
  Future<void> cancelPurchase(String purchaseId) async {
    await _api.patch<void>('/seller/ar-tokens/purchases/$purchaseId/cancel');
  }

  @override
  Future<TariffPaymentInstructions> paymentInstructions() async {
    final body = await _api.get<Map<String, dynamic>>(
      '/seller/ar-tokens/payment-instructions',
    );
    return TariffPaymentInstructions(
      cardNumber: body['card_number'] as String? ?? '',
      cardHolder: body['card_holder'] as String? ?? '',
      bankName: body['bank_name'] as String? ?? '',
      note: body['note'] as String? ?? '',
      telegramSupportUrl: body['telegram_support_url'] as String? ?? '',
    );
  }

  @override
  Future<String> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  }) async {
    final userId = _auth.currentUserId;
    if (userId == null) {
      throw StateError('auth_required');
    }
    final ext = fileExtension.toLowerCase();
    final path =
        '$userId/ar-token-${DateTime.now().millisecondsSinceEpoch}.$ext';
    final result = await _uploads.upload(
      bucket: R2Bucket.paymentReceipts,
      path: path,
      bytes: await file.readAsBytes(),
      contentType: _contentType(ext),
    );
    return result.path;
  }

  @override
  Future<ArTokenPurchase> submitManualPurchase({
    required String packageCode,
    required String paymentScreenshotPath,
  }) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/seller/ar-tokens/purchases/manual',
      body: {
        'package_code': packageCode,
        'payment_screenshot_path': paymentScreenshotPath,
      },
    );
    return ArTokenPurchase.fromJson(body);
  }

  String _contentType(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg',
  };

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
