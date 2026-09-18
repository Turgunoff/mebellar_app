import '../../core/result/result.dart';
import '../models/seller_wallet.dart';
import 'payment_repository.dart';

/// Seller wallet surface — balance/debt state, ledger, automated top-ups.
/// The Woody impl talks to `/seller/wallet*`; tests mock this interface.
///
/// **Fully `Result<T>`.** Every method here moves money or reports on money
/// that moved, which is the `Result` side of the error-handling boundary
/// (`.claude/rules/error-handling.md`): the caller has to pattern-match the
/// failure, so a swallowed error is a compile-time hole rather than a silent
/// no-op. This was the last money-command repository still on `throw` (T-10);
/// nothing in this file throws now.
abstract class SellerWalletRepository {
  /// Balance + debt state + the most recent ledger rows ([recent] of them).
  Future<Result<SellerWallet>> fetch({int recent = 20});

  /// Opens a self-serve top-up: records a pending deposit intent and returns the
  /// Payme/Click deep-link to open (`POST /seller/wallet/deposit`). The webhook
  /// credits the balance on confirmation; the app persists the returned
  /// `reference` (= deposit id) and polls [depositStatus] on return.
  Future<Result<CheckoutLink>> createDeposit({
    required int amount,
    required PaymentProvider provider,
  });

  /// Settlement status of a wallet top-up the seller just opened in the payment
  /// app (`GET /seller/wallet/deposit/{id}/status`): `pending` → `paid` once the
  /// webhook credits the balance, or `cancelled`.
  ///
  /// `Ok('pending')` and `Err` are NOT the same thing and callers must not
  /// collapse them: the first is the server saying "not settled yet", the
  /// second is "we never reached the server". Only the first justifies giving
  /// up on a poll.
  Future<Result<String>> depositStatus(String depositId);

  /// Manual card transfer + receipt screenshot (`POST /seller/wallet/topups`).
  /// Creates a pending moderation row; admin approval credits the balance.
  Future<Result<WalletTopUp>> submitManualTopup({
    required int amount,
    required String paymentScreenshotPath,
  });

  /// Manual top-up moderation rows, newest first (`GET /seller/wallet/topups`).
  Future<Result<List<WalletTopUp>>> fetchTopUps();

  /// Withdraw a pending manual top-up (`PATCH /seller/wallet/topups/{id}/cancel`).
  Future<Result<void>> cancelTopUp(String topUpId);

  /// Withdraw a pending online deposit intent — e.g. an abandoned or failed
  /// Payme/Click checkout — so a new attempt isn't blocked
  /// (`PATCH /seller/wallet/deposit/{id}/cancel`).
  Future<Result<void>> cancelDeposit(String depositId);

  /// Ledger history (`GET /seller/wallet/transactions`).
  Future<Result<List<WalletTransaction>>> fetchTransactions({
    int limit = 50,
    int offset = 0,
  });

  /// Request a card payout (`POST /seller/wallet/withdraw`). Holds the amount
  /// immediately; admin approve keeps it, reject refunds.
  Future<Result<WalletWithdrawal>> requestWithdrawal({
    required int amount,
    required String cardNumber,
  });

  /// Withdrawal requests (`GET /seller/wallet/withdrawals`).
  Future<Result<List<WalletWithdrawal>>> fetchWithdrawals({String? status});
}
