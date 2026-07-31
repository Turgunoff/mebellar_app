import 'dart:io';

import '../../core/auth/auth_repository.dart';
import '../../core/error/failure.dart';
import '../../core/network/woody_api_client.dart';
import '../../core/result/result.dart';
import '../../core/storage/r2_upload_client.dart';
import '../models/tariff.dart';
import 'payment_repository.dart';
import 'tariff_repository.dart';

/// REST-backed tariff surface — `/seller/tariff/*`. Payment screenshots upload
/// to the private `payment-receipts` R2 bucket; the path is then passed to
/// `POST /seller/tariff/subscribe`. There's no realtime tariff feed yet, so the
/// two watch streams poll (the pending screen also runs a client-side 24h SLA
/// countdown, so a coarse poll is enough).
class WoodyTariffRepository implements TariffRepository {
  WoodyTariffRepository({
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
  Future<Result<List<SubscriptionPlan>>> fetchPlans() => runCatching(() async {
    final rows = await _api.get<List<dynamic>>('/seller/tariff/plans');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPlan.fromJson)
        .toList(growable: false);
  });

  @override
  Future<Result<TariffSnapshot>> currentSnapshot() => runCatching(() async {
    final body = await _api.get<Map<String, dynamic>>('/seller/tariff/current');
    final startedRaw = body['started_at'] as String?;
    final expiresRaw = body['expires_at'] as String?;
    return TariffSnapshot(
      plan: TariffPlan.fromCode(body['plan_code'] as String?),
      activeProductsCount:
          (body['active_products_count'] as num?)?.toInt() ?? 0,
      maxProducts: (body['max_products'] as num?)?.toInt(),
      startedAt: startedRaw == null ? null : DateTime.tryParse(startedRaw),
      expiresAt: expiresRaw == null ? null : DateTime.tryParse(expiresRaw),
      ai3dUsed: (body['ai_3d_used'] as num?)?.toInt() ?? 0,
      ai3dLimit: (body['ai_3d_limit'] as num?)?.toInt(),
    );
  });

  @override
  Future<Result<TariffSubscription?>> currentPending() => runCatching(() async {
    final body = await _api.get<dynamic>('/seller/tariff/pending');
    if (body is! Map<String, dynamic>) return null;
    return TariffSubscription.fromJson(body);
  });

  @override
  Future<Result<List<TariffSubscription>>> history() => runCatching(() async {
    final rows = await _api.get<List<dynamic>>('/seller/tariff/history');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(TariffSubscription.fromJson)
        .toList(growable: false);
  });

  @override
  Future<Result<TariffPaymentInstructions>> paymentInstructions() =>
      runCatching(() async {
        final body = await _api.get<Map<String, dynamic>>(
          '/seller/tariff/payment-instructions',
        );
        return TariffPaymentInstructions(
          cardNumber: body['card_number'] as String? ?? '',
          cardHolder: body['card_holder'] as String? ?? '',
          bankName: body['bank_name'] as String? ?? '',
          note: body['note'] as String? ?? '',
          telegramSupportUrl: body['telegram_support_url'] as String? ?? '',
        );
      });

  @override
  Future<Result<String>> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  }) => runCatching(() async {
    final userId = _auth.currentUserId;
    if (userId == null) {
      throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
    }
    final ext = fileExtension.toLowerCase();
    final path =
        '$userId/receipt-${DateTime.now().millisecondsSinceEpoch}.$ext';
    final result = await _uploads.upload(
      bucket: R2Bucket.paymentReceipts,
      path: path,
      bytes: await file.readAsBytes(),
      contentType: _contentType(ext),
    );
    return result.path;
  });

  @override
  Future<Result<TariffSubscription>> upgrade(TariffUpgradeInput input) =>
      runCatching(() async {
        final body = await _api.post<Map<String, dynamic>>(
          '/seller/tariff/subscribe',
          body: {
            'plan_code': input.plan.code,
            'billing_period': input.period.code,
            'payment_screenshot_path': input.paymentScreenshotUrl,
          },
        );
        return TariffSubscription.fromJson(body);
      });

  @override
  Future<Result<void>> cancelPending(String subscriptionId) =>
      runCatching(() async {
        await _api.patch<dynamic>(
          '/seller/tariff/receipts/$subscriptionId/cancel',
        );
      });

  @override
  Future<Result<TariffCheckout>> buyPlan({
    required TariffPlan plan,
    required BillingPeriod period,
    required PaymentProvider provider,
  }) => runCatching(() async {
    final body = await _api.post<Map<String, dynamic>>(
      '/seller/tariff/buy',
      body: {
        'plan_code': plan.code,
        'billing_period': period.code,
        'provider': provider.slug,
      },
    );
    return TariffCheckout(
      url: body['checkout_url'] as String? ?? '',
      reference: body['reference'] as String?,
    );
  });

  @override
  Stream<TariffSubscription?> watchPending() async* {
    while (true) {
      yield (await currentPending()).valueOrNull;
      await Future<void>.delayed(const Duration(seconds: 20));
    }
  }

  @override
  Stream<TariffPlan> watchCurrentPlan() async* {
    while (true) {
      final snap = (await currentSnapshot()).valueOrNull;
      if (snap != null) yield snap.plan;
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }

  String _contentType(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg',
  };
}
