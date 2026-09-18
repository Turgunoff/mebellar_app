import '../../core/network/api_error_messages.dart';
import '../../core/network/woody_api_client.dart';
import '../../core/result/result.dart';
import '../models/seller_wallet.dart';
import 'payment_repository.dart';
import 'seller_wallet_repository.dart';

/// REST-backed wallet — `GET /seller/wallet`, `POST /seller/wallet/deposit`,
/// `POST /seller/wallet/topups`, `GET /seller/wallet/deposit/{id}/status`.
/// Online top-ups open a Payme/Click deep-link (webhook-credited); manual
/// top-ups upload a receipt screenshot for admin approval.
///
/// Every method wraps its body in [runCatching] with the shared
/// [apiErrorToFailure] bridge, so the `Failure.message` a caller renders is the
/// same localised string the UI used to derive from the caught `ApiError`.
class WoodySellerWalletRepository implements SellerWalletRepository {
  WoodySellerWalletRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<Result<SellerWallet>> fetch({int recent = 20}) => runCatching(
        () async {
          final body = await _api.get<Map<String, dynamic>>(
            '/seller/wallet',
            query: {'recent': recent},
          );
          return SellerWallet.fromJson(body);
        },
        onError: (error, _) => apiErrorToFailure(error),
      );

  @override
  Future<Result<CheckoutLink>> createDeposit({
    required int amount,
    required PaymentProvider provider,
  }) =>
      runCatching(
        () async {
          final body = await _api.post<Map<String, dynamic>>(
            '/seller/wallet/deposit',
            body: {'amount': amount, 'provider': provider.slug},
          );
          return CheckoutLink.fromJson(body);
        },
        onError: (error, _) => apiErrorToFailure(error),
      );

  @override
  Future<Result<String>> depositStatus(String depositId) => runCatching(
        () async {
          final body = await _api.get<Map<String, dynamic>>(
            '/seller/wallet/deposit/$depositId/status',
          );
          // A 200 with no `status` key means "the server answered but has not
          // settled yet" — that is an Ok('pending'), not a failure. Only a
          // transport/HTTP error reaches the Err arm.
          return body['status'] as String? ?? 'pending';
        },
        onError: (error, _) => apiErrorToFailure(error),
      );

  @override
  Future<Result<WalletTopUp>> submitManualTopup({
    required int amount,
    required String paymentScreenshotPath,
  }) =>
      runCatching(
        () async {
          final body = await _api.post<Map<String, dynamic>>(
            '/seller/wallet/topups',
            body: {
              'amount': amount,
              'payment_screenshot_path': paymentScreenshotPath,
            },
          );
          return WalletTopUp.fromJson(body);
        },
        onError: (error, _) => apiErrorToFailure(error),
      );

  @override
  Future<Result<List<WalletTopUp>>> fetchTopUps() => runCatching(
        () async {
          final body = await _api.get<List<dynamic>>('/seller/wallet/topups');
          return body
              .whereType<Map<String, dynamic>>()
              .map(WalletTopUp.fromJson)
              .toList(growable: false);
        },
        onError: (error, _) => apiErrorToFailure(error),
      );

  @override
  Future<Result<void>> cancelTopUp(String topUpId) => runCatching(
        () => _api.patch<void>('/seller/wallet/topups/$topUpId/cancel'),
        onError: (error, _) => apiErrorToFailure(error),
      );

  @override
  Future<Result<void>> cancelDeposit(String depositId) => runCatching(
        () => _api.patch<void>('/seller/wallet/deposit/$depositId/cancel'),
        onError: (error, _) => apiErrorToFailure(error),
      );

  @override
  Future<Result<List<WalletTransaction>>> fetchTransactions({
    int limit = 50,
    int offset = 0,
  }) =>
      runCatching(
        () async {
          final body = await _api.get<List<dynamic>>(
            '/seller/wallet/transactions',
            query: {'limit': limit, 'offset': offset},
          );
          return body
              .whereType<Map<String, dynamic>>()
              .map(WalletTransaction.fromJson)
              .toList(growable: false);
        },
        onError: (error, _) => apiErrorToFailure(error),
      );

  @override
  Future<Result<WalletWithdrawal>> requestWithdrawal({
    required int amount,
    required String cardNumber,
  }) =>
      runCatching(
        () async {
          final body = await _api.post<Map<String, dynamic>>(
            '/seller/wallet/withdraw',
            body: {
              'amount': amount,
              // The card number arrives from a masked/spaced text field; the
              // backend stores digits only. Stripping here (not at the call
              // site) keeps every caller honest.
              'card_number': cardNumber.replaceAll(RegExp(r'\D'), ''),
            },
          );
          return WalletWithdrawal.fromJson(body);
        },
        onError: (error, _) => apiErrorToFailure(error),
      );

  @override
  Future<Result<List<WalletWithdrawal>>> fetchWithdrawals({String? status}) =>
      runCatching(
        () async {
          final body = await _api.get<List<dynamic>>(
            '/seller/wallet/withdrawals',
            query: {'status': ?status},
          );
          return body
              .whereType<Map<String, dynamic>>()
              .map(WalletWithdrawal.fromJson)
              .toList(growable: false);
        },
        onError: (error, _) => apiErrorToFailure(error),
      );
}
