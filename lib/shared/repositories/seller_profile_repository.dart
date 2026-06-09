import '../../core/network/woody_api_client.dart';

/// The three seller-profile reads the profile header needs. Each returns the
/// raw woody_backend row (or throws [ApiError]); the cubit classifies the
/// outcome (ok / 404-absent / failed) and decides the fallback, so this is a
/// thin seam over [WoodyApiClient] purely to keep [SellerProfileCubit]
/// testable and off the network layer.
abstract class SellerProfileRepository {
  Future<Map<String, dynamic>> fetchMe(); // GET /seller/me
  Future<Map<String, dynamic>> fetchShop(); // GET /seller/shop
  Future<Map<String, dynamic>> fetchTariffCurrent(); // GET /seller/tariff/current
}

class WoodySellerProfileRepository implements SellerProfileRepository {
  WoodySellerProfileRepository(this._api);

  final WoodyApiClient _api;

  @override
  Future<Map<String, dynamic>> fetchMe() =>
      _api.get<Map<String, dynamic>>('/seller/me');

  @override
  Future<Map<String, dynamic>> fetchShop() =>
      _api.get<Map<String, dynamic>>('/seller/shop');

  @override
  Future<Map<String, dynamic>> fetchTariffCurrent() =>
      _api.get<Map<String, dynamic>>('/seller/tariff/current');
}
