import 'package:dio/dio.dart';

import '../models/product.dart';

abstract class FavoritesRepository {
  Stream<Set<String>> watchIds();
  Set<String> get currentIds;
  bool isFavorite(String productId);

  Future<List<Product>> list();
  Future<void> toggle(Product product);
  Future<void> remove(String productId);
}

class RemoteFavoritesRepository implements FavoritesRepository {
  RemoteFavoritesRepository(this._dio);

  final Dio _dio;
  final Set<String> _ids = <String>{};

  @override
  Set<String> get currentIds => Set.unmodifiable(_ids);

  @override
  bool isFavorite(String productId) => _ids.contains(productId);

  @override
  Stream<Set<String>> watchIds() => Stream<Set<String>>.empty();

  @override
  Future<List<Product>> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/v1/favorites');
    final items = (res.data?['data'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();
    _ids
      ..clear()
      ..addAll(items.map((p) => p.id));
    return items;
  }

  @override
  Future<void> toggle(Product product) async {
    if (_ids.contains(product.id)) {
      await remove(product.id);
    } else {
      await _dio.post<dynamic>(
        '/api/v1/favorites',
        data: {'product_id': product.id},
      );
      _ids.add(product.id);
    }
  }

  @override
  Future<void> remove(String productId) async {
    await _dio.delete<dynamic>('/api/v1/favorites/$productId');
    _ids.remove(productId);
  }
}
