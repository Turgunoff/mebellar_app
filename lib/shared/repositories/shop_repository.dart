import 'package:dio/dio.dart';

import '../models/paginated.dart';
import '../models/shop.dart';

abstract class ShopRepository {
  Future<Paginated<Shop>> list({
    bool? featured,
    int page = 1,
    int perPage = 20,
  });

  Future<Shop> getBySlug(String slug);
}

class RemoteShopRepository implements ShopRepository {
  RemoteShopRepository(this._dio);

  final Dio _dio;

  @override
  Future<Paginated<Shop>> list({
    bool? featured,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/shops',
      queryParameters: {
        'featured': ?featured,
        'page': page,
        'per_page': perPage,
      },
    );
    return Paginated.fromJson(response.data ?? const {}, Shop.fromJson);
  }

  @override
  Future<Shop> getBySlug(String slug) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/shops/$slug',
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected /shops/$slug payload');
    }
    return Shop.fromJson(data);
  }
}
