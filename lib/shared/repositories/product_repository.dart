import 'package:dio/dio.dart';

import '../models/paginated.dart';
import '../models/product.dart';

enum ProductSort {
  createdAt('created_at'),
  priceAsc('price_asc'),
  priceDesc('price_desc'),
  popular('popular');

  const ProductSort(this.code);
  final String code;
}

class ProductFilter {
  const ProductFilter({
    this.categorySlug,
    this.shopSlug,
    this.search,
    this.minPrice,
    this.maxPrice,
    this.sort = ProductSort.createdAt,
    this.featured,
  });

  final String? categorySlug;
  final String? shopSlug;
  final String? search;
  final num? minPrice;
  final num? maxPrice;
  final ProductSort sort;
  final bool? featured;

  Map<String, dynamic> toQuery() {
    return {
      if (categorySlug != null) 'category': categorySlug,
      if (shopSlug != null) 'shop': shopSlug,
      if (search != null && search!.isNotEmpty) 'search': search,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      'sort': sort.code,
      if (featured != null) 'featured': featured,
    };
  }

  ProductFilter copyWith({
    String? categorySlug,
    String? shopSlug,
    String? search,
    num? minPrice,
    num? maxPrice,
    ProductSort? sort,
    bool? featured,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return ProductFilter(
      categorySlug: categorySlug ?? this.categorySlug,
      shopSlug: shopSlug ?? this.shopSlug,
      search: search ?? this.search,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      sort: sort ?? this.sort,
      featured: featured ?? this.featured,
    );
  }
}

abstract class ProductRepository {
  Future<Paginated<Product>> list({
    ProductFilter filter = const ProductFilter(),
    int page = 1,
    int perPage = 20,
  });

  Future<Product> getBySlug(String slug);

  Future<Paginated<Product>> search(String query, {int page = 1});
}

class RemoteProductRepository implements ProductRepository {
  RemoteProductRepository(this._dio);

  final Dio _dio;

  @override
  Future<Paginated<Product>> list({
    ProductFilter filter = const ProductFilter(),
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/products',
      queryParameters: {
        ...filter.toQuery(),
        'page': page,
        'per_page': perPage,
      },
    );
    return Paginated.fromJson(
      response.data ?? const {},
      Product.fromJson,
    );
  }

  @override
  Future<Product> getBySlug(String slug) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/products/$slug',
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected /products/$slug payload');
    }
    return Product.fromJson(data);
  }

  @override
  Future<Paginated<Product>> search(String query, {int page = 1}) {
    return list(filter: ProductFilter(search: query), page: page);
  }
}
