import '../../core/network/woody_api_client.dart';
import '../models/supabase_product_model.dart';
import 'supabase_product_data_source.dart';

/// Drop-in replacement for `SupabaseProductRepository` that calls the
/// `/catalog/products*` REST endpoints on api.woody.uz.
///
/// The backend deliberately mirrors the PostgREST embed shape Flutter parses
/// today (`shops: {name}`, `product_variants: [{price, discount_price}]`)
/// so `SupabaseProductModel.fromJson` works unchanged — only the transport
/// flips.
class WoodyProductRepository extends SupabaseProductDataSource {
  WoodyProductRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  static const _basePath = '/catalog/products';

  @override
  Future<List<SupabaseProductModel>> listByCategory({
    required String categoryId,
    String? subcategoryId,
    ProductSearchFilter filter = const ProductSearchFilter(),
  }) async {
    final query = <String, dynamic>{
      'category_id': categoryId,
      ..._sortQuery(filter.sort),
      ..._facetQuery(filter),
      'limit': 200,
    };
    if (subcategoryId != null) {
      query['subcategory_id'] = subcategoryId;
    }
    return _postFilter(await _listRequest(query), filter);
  }

  @override
  Future<List<SupabaseProductModel>> listBySubcategory({
    required String subcategoryId,
  }) async {
    return _listRequest({
      'subcategory_id': subcategoryId,
      'sort': 'newest',
      'limit': 200,
    });
  }

  @override
  Future<SupabaseProductModel> getById(String id) async {
    final body = await _api.get<Map<String, dynamic>>('$_basePath/$id');
    return SupabaseProductModel.fromJson(body);
  }

  @override
  Future<List<SupabaseProductModel>> listAll({int limit = 10}) {
    return _listRequest({'sort': 'newest', 'limit': limit});
  }

  @override
  Future<List<SupabaseProductModel>> search(
    String query, {
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = 30,
  }) async {
    final term = query.trim();
    if (term.isEmpty && filter.isDefault) return const [];
    // `discountedOnly` is post-filtered in Dart (the discount lives on a
    // variant row, not the product), so we over-fetch slightly when active
    // to keep the visible page size stable.
    final fetchLimit = filter.discountedOnly ? limit * 2 : limit;
    final q = <String, dynamic>{
      if (term.isNotEmpty) 'search': term,
      ..._sortQuery(filter.sort),
      ..._facetQuery(filter),
      'limit': fetchLimit,
    };
    final rows = await _listRequest(q);
    final filtered = _postFilter(rows, filter);
    return filtered.length > limit ? filtered.sublist(0, limit) : filtered;
  }

  @override
  Future<List<SupabaseProductModel>> listSimilar(
    String productId, {
    int limit = 10,
  }) async {
    final body = await _api.get<List<dynamic>>(
      '$_basePath/$productId/similar',
      query: {'limit': limit},
    );
    return body
        .whereType<Map<String, dynamic>>()
        .map(SupabaseProductModel.fromJson)
        .toList(growable: false);
  }

  Future<List<SupabaseProductModel>> _listRequest(
    Map<String, dynamic> query,
  ) async {
    final body = await _api.get<Map<String, dynamic>>(
      _basePath,
      query: query.map((k, v) {
        if (v is List) return MapEntry(k, v.map((e) => e.toString()).toList());
        return MapEntry(k, v);
      }),
    );
    final rows = body['rows'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(SupabaseProductModel.fromJson)
        .toList(growable: false);
  }

  Map<String, dynamic> _sortQuery(ProductSearchSort sort) {
    return {
      'sort': switch (sort) {
        ProductSearchSort.newest => 'newest',
        ProductSearchSort.priceAsc => 'price_asc',
        ProductSearchSort.priceDesc => 'price_desc',
      },
    };
  }

  Map<String, dynamic> _facetQuery(ProductSearchFilter filter) {
    return {
      if (filter.colors.isNotEmpty) 'color': filter.colors.toList(),
      if (filter.minPrice != null) 'min_price': filter.minPrice,
      if (filter.maxPrice != null) 'max_price': filter.maxPrice,
      if (filter.inStockOnly) 'in_stock': true,
      if (filter.deliveryOnly) 'has_delivery': true,
    };
  }

  /// `discountedOnly` lives on a variant row; the API can't filter on it
  /// without re-shaping the embed, so we drop non-discounted rows here.
  List<SupabaseProductModel> _postFilter(
    List<SupabaseProductModel> rows,
    ProductSearchFilter filter,
  ) {
    if (!filter.discountedOnly) return rows;
    return rows.where((p) => p.hasDiscount).toList(growable: false);
  }
}

