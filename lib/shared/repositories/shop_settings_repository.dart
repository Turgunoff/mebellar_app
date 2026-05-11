import 'dart:io';

import 'package:dio/dio.dart';

import '../models/shop_settings.dart';

abstract class ShopSettingsRepository {
  Stream<ShopSettings> watch();
  Future<ShopSettings> get();
  Future<ShopSettings> save(ShopSettings settings);
  Future<String> uploadAsset({
    required String kind,
    required File file,
    required String fileExtension,
  });
}

class RemoteShopSettingsRepository implements ShopSettingsRepository {
  RemoteShopSettingsRepository(this._dio);
  // ignore: unused_field — Sprint 8 backend wires real endpoints.
  final Dio _dio;

  @override
  Stream<ShopSettings> watch() => const Stream.empty();

  @override
  Future<ShopSettings> get() =>
      throw UnimplementedError('Remote shop settings — Sprint 8 backend');

  @override
  Future<ShopSettings> save(ShopSettings settings) =>
      throw UnimplementedError('Remote shop settings — Sprint 8 backend');

  @override
  Future<String> uploadAsset({
    required String kind,
    required File file,
    required String fileExtension,
  }) =>
      throw UnimplementedError('Remote shop settings — Sprint 8 backend');
}
