import 'package:dio/dio.dart';

import '../models/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> tree();
  Future<Category> getBySlug(String slug);
}

class RemoteCategoryRepository implements CategoryRepository {
  RemoteCategoryRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Category>> tree() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/categories');
    final data = response.data?['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Category.fromJson)
        .toList(growable: false);
  }

  @override
  Future<Category> getBySlug(String slug) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/categories/$slug',
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected /categories/$slug payload');
    }
    return Category.fromJson(data);
  }
}
