import '../../core/network/woody_api_client.dart';
import '../models/seller_wallet.dart';
import 'payment_repository.dart';
import 'seller_wallet_repository.dart';

/// REST-backed wallet — `GET /seller/wallet`, `POST /seller/wallet/deposit`,
/// `POST /seller/wallet/topups`, `GET /seller/wallet/deposit/{id}/status`.
/// Online top-ups open a Payme/Click deep-link (webhook-credited); manual
/// top-ups upload a receipt screenshot for admin approval.
class WoodySellerWalletRepository implements SellerWalletRepository {
  WoodySellerWalletRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<SellerWallet> fetch({int recent = 20}) async {
    final body = await _api.get<Map<String, dynamic>>(
      '/seller/wallet',
      query: {'recent': recent},
    );
    return SellerWallet.fromJson(body);
  }

  @override
  Future<CheckoutLink> createDeposit({
    required int amount,
    required PaymentProvider provider,
  }) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/seller/wallet/deposit',
      body: {'amount': amount, 'provider': provider.slug},
    );
    return CheckoutLink.fromJson(body);
  }

  @override
  Future<String> depositStatus(String depositId) async {
    final body = await _api.get<Map<String, dynamic>>(
      '/seller/wallet/deposit/$depositId/status',
    );
    return body['status'] as String? ?? 'pending';
  }

  @override
  Future<WalletTopUp> submitManualTopup({
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

  @override
  Future<List<WalletTopUp>> fetchTopUps() async {
    final body = await _api.get<List<dynamic>>('/seller/wallet/topups');
    return body
        .whereType<Map<String, dynamic>>()
        .map(WalletTopUp.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> cancelTopUp(String topUpId) async {
    await _api.patch<void>('/seller/wallet/topups/$topUpId/cancel');
  }

  @override
  Future<void> cancelDeposit(String depositId) async {
    await _api.patch<void>('/seller/wallet/deposit/$depositId/cancel');
  }

  @override
  Future<List<WalletTransaction>> fetchTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    final body = await _api.get<List<dynamic>>(
      '/seller/wallet/transactions',
      query: {'limit': limit, 'offset': offset},
    );
    return body
        .whereType<Map<String, dynamic>>()
        .map(WalletTransaction.fromJson)
        .toList(growable: false);
  }
}
