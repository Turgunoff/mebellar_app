import '../../core/result/result.dart';
import '../models/shop_service_config.dart';

/// Selectable delivery / service configuration tied to the seller's shop.
///
/// ROADMAP B.1 — migrated to the `Result<T, Failure>` contract: callers
/// pattern-match the outcome instead of wrapping every call in try/catch.
abstract class SellerServicesRepository {
  Future<Result<List<ShopServiceConfig>>> list();
  Future<Result<List<ShopServiceConfig>>> save(List<ShopServiceConfig> configs);
}
