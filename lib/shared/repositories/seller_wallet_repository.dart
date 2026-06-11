import 'dart:io';

import '../models/seller_wallet.dart';

/// Seller wallet surface — balance/debt state, ledger, top-up requests.
/// The Woody impl talks to `/seller/wallet*`; tests mock this interface.
abstract class SellerWalletRepository {
  /// Balance + debt state + the most recent ledger rows ([recent] of them).
  Future<SellerWallet> fetch({int recent = 20});

  /// Uploads the payment screenshot to the private `payment-receipts` bucket
  /// and returns the storage path to pass into [submitTopUp].
  Future<String> uploadPaymentScreenshot({
    required File file,
    required String fileExtension,
  });

  /// Files a top-up request for admin moderation; approval credits the
  /// wallet (and lifts the debt freeze if the balance clears the floor).
  Future<WalletTopUp> submitTopUp({
    required int amount,
    required String paymentScreenshotPath,
  });
}
