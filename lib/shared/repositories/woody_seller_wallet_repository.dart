import '../../core/network/woody_api_client.dart';
import '../models/seller_wallet.dart';
import 'payment_repository.dart';
import 'seller_wallet_repository.dart';

/// REST-backed wallet — `GET /seller/wallet`, `POST /seller/wallet/deposit`,
/// `GET /seller/wallet/deposit/{id}/status`. Top-ups are automated Payme/Click
/// deep-links (webhook-credited); there is no screenshot upload anymore.
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
}
