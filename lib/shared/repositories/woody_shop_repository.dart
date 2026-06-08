import '../../core/network/woody_api_client.dart';
import '../../core/result/result.dart';
import '../models/product_model.dart';
import '../models/shop_profile.dart';
import 'shop_repository.dart';

/// Woody REST [ShopRepository] — reads the public catalogue shop surface.
class WoodyShopRepository implements ShopRepository {
  WoodyShopRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<Result<ShopProfile>> shopById(String shopId) => runCatching(() async {
    final body = await _api.get<Map<String, dynamic>>('/catalog/shops/$shopId');
    return ShopProfile.fromJson(body);
  });

  @override
  Future<List<ProductModel>> productsByShop(
    String shopId, {
    int limit = 50,
  }) async {
    final body = await _api.get<Map<String, dynamic>>(
      '/catalog/products',
      query: {'shop_id': shopId, 'sort': 'newest', 'limit': limit},
    );
    final rows = body['rows'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList(growable: false);
  }
}
