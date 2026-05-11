import 'package:dio/dio.dart';

import '../models/shop_service_config.dart';

abstract class SellerServicesRepository {
  Future<List<ShopServiceConfig>> list();
  Future<List<ShopServiceConfig>> save(List<ShopServiceConfig> configs);
}

class RemoteSellerServicesRepository implements SellerServicesRepository {
  RemoteSellerServicesRepository(this._dio);
  // ignore: unused_field — Sprint 8 backend wires real PUT endpoint.
  final Dio _dio;

  @override
  Future<List<ShopServiceConfig>> list() =>
      throw UnimplementedError('Remote seller services — Sprint 8 backend');

  @override
  Future<List<ShopServiceConfig>> save(List<ShopServiceConfig> configs) =>
      throw UnimplementedError('Remote seller services — Sprint 8 backend');
}
