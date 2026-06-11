import 'dart:io';

import '../../core/auth/auth_repository.dart';
import '../../core/error/failure.dart';
import '../../core/network/woody_api_client.dart';
import '../../core/storage/r2_upload_client.dart';
import '../models/seller_wallet.dart';
import 'seller_wallet_repository.dart';

/// REST-backed wallet — `GET /seller/wallet`, `POST /seller/wallet/topups`.
/// Top-up screenshots ride the same private `payment-receipts` bucket the
/// tariff receipts use.
class WoodySellerWalletRepository implements SellerWalletRepository {
  WoodySellerWalletRepository({
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
  Future<SellerWallet> fetch({int recent = 20}) async {
    final body = await _api.get<Map<String, dynamic>>(
      '/seller/wallet',
      query: {'recent': recent},
    );
    return SellerWallet.fromJson(body);
  }

  @override
  Future<String> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  }) async {
    final userId = _auth.currentUserId;
    if (userId == null) {
      throw const AuthFailure(message: 'Tizimga kirish talab qilinadi');
    }
    final ext = fileExtension.toLowerCase();
    final path =
        '$userId/wallet-${DateTime.now().millisecondsSinceEpoch}.$ext';
    final result = await _uploads.upload(
      bucket: R2Bucket.paymentReceipts,
      path: path,
      bytes: await file.readAsBytes(),
      contentType: switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      },
    );
    return result.path;
  }

  @override
  Future<WalletTopUp> submitTopUp({
    required int amount,
    required String paymentScreenshotPath,
  }) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/seller/wallet/topups',
      body: {
        'amount': amount,
        'payment_screenshot_path': paymentScreenshotPath,
      },
    );
    return WalletTopUp.fromJson(body);
  }
}
