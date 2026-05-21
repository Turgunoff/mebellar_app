import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/shared/models/shop_service_config.dart';
import 'package:woody_app/shared/repositories/seller_services_repository.dart';
import 'mock_shop_settings.dart';

class MockSellerServicesRepository implements SellerServicesRepository {
  MockSellerServicesRepository() {
    _configs = MockShopSettings.defaultServices();
  }

  static const _delay = Duration(milliseconds: 250);

  List<ShopServiceConfig> _configs = const [];

  @override
  Future<Result<List<ShopServiceConfig>>> list() async {
    await Future<void>.delayed(_delay);
    return Ok(List<ShopServiceConfig>.unmodifiable(_configs));
  }

  @override
  Future<Result<List<ShopServiceConfig>>> save(
    List<ShopServiceConfig> configs,
  ) async {
    await Future<void>.delayed(_delay);
    _configs = List<ShopServiceConfig>.unmodifiable(configs);
    return Ok(_configs);
  }
}
