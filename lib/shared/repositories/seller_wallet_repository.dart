import '../models/seller_wallet.dart';
import 'payment_repository.dart';

/// Seller wallet surface — balance/debt state, ledger, automated top-ups.
/// The Woody impl talks to `/seller/wallet*`; tests mock this interface.
abstract class SellerWalletRepository {
  /// Balance + debt state + the most recent ledger rows ([recent] of them).
  Future<SellerWallet> fetch({int recent = 20});

  /// Opens a self-serve top-up: records a pending deposit intent and returns the
  /// Payme/Click deep-link to open (`POST /seller/wallet/deposit`). The webhook
  /// credits the balance on confirmation; the app persists the returned
  /// `reference` (= deposit id) and polls [depositStatus] on return.
  Future<CheckoutLink> createDeposit({
    required int amount,
    required PaymentProvider provider,
  });

  /// Settlement status of a wallet top-up the seller just opened in the payment
  /// app (`GET /seller/wallet/deposit/{id}/status`): `pending` → `paid` once the
  /// webhook credits the balance, or `cancelled`.
  Future<String> depositStatus(String depositId);

  /// Manual card transfer + receipt screenshot (`POST /seller/wallet/topups`).
  /// Creates a pending moderation row; admin approval credits the balance.
  Future<WalletTopUp> submitManualTopup({
    required int amount,
    required String paymentScreenshotPath,
  });

  /// Manual top-up moderation rows, newest first (`GET /seller/wallet/topups`).
  Future<List<WalletTopUp>> fetchTopUps();

  /// Withdraw a pending manual top-up (`PATCH /seller/wallet/topups/{id}/cancel`).
  Future<void> cancelTopUp(String topUpId);

  /// Ledger history (`GET /seller/wallet/transactions`).
  Future<List<WalletTransaction>> fetchTransactions({
    int limit = 50,
    int offset = 0,
  });
}
