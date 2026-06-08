import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../models/product_model.dart';
import '../models/shop_profile.dart';

/// Public, customer-facing reads for a seller's shop: the profile payload
/// (`GET /catalog/shops/{id}`) and the shop's approved product listing
/// (`GET /catalog/products?shop_id=`).
abstract class ShopRepository {
  /// The public shop profile. `Err` on a missing shop (404) or transport
  /// failure — the screen renders an error state in that case.
  Future<Result<ShopProfile>> shopById(String shopId);

  /// Approved products for [shopId], newest first. Returns an empty list on a
  /// transport error so the profile still renders with its header + stats even
  /// when only the listing is unavailable.
  Future<List<ProductModel>> productsByShop(String shopId, {int limit = 50});
}

/// In-memory [ShopRepository] for tests. Seed [shop] / [products] (or
/// [shopError]) per case; both calls echo whatever is configured.
class MockShopRepository implements ShopRepository {
  MockShopRepository({this.shop, this.products = const [], this.shopError});

  ShopProfile? shop;
  List<ProductModel> products;
  Failure? shopError;

  @override
  Future<Result<ShopProfile>> shopById(String shopId) async {
    final error = shopError;
    if (error != null) return Result.err(error);
    final value = shop;
    if (value == null) {
      return const Result.err(UnknownFailure(message: 'shop_not_found'));
    }
    return Result.ok(value);
  }

  @override
  Future<List<ProductModel>> productsByShop(
    String shopId, {
    int limit = 50,
  }) async => products;
}
