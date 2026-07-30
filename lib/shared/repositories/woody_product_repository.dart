import '../../core/network/woody_api_client.dart';
import '../models/product_model.dart';
import 'product_data_source.dart';

/// Calls the
/// `/catalog/products*` REST endpoints on api.woody.uz.
///
/// The backend deliberately mirrors the PostgREST embed shape Flutter parses
/// today (`shops: {name}`, `product_variants: [{price, discount_price}]`)
/// so `ProductModel.fromJson` works unchanged — only the transport
/// flips.
class WoodyProductRepository extends ProductDataSource {
  WoodyProductRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  static const _basePath = '/catalog/products';

  @override
  Future<ProductFeedPage> listByCategory({
    required String categoryId,
    String? subcategoryId,
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = kCategoryPageSize,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'category_id': categoryId,
      ..._sortQuery(filter.sort),
      ..._facetQuery(filter),
      'limit': limit,
      'offset': offset,
    };
    if (subcategoryId != null) {
      query['subcategory_id'] = subcategoryId;
    }
    return _pageRequest(query);
  }

  @override
  Future<List<ProductModel>> listBySubcategory({
    required String subcategoryId,
  }) async {
    return _listRequest({
      'subcategory_id': subcategoryId,
      'sort': 'newest',
      'limit': 200,
    });
  }

  @override
  Future<ProductModel> getById(String id) async {
    final body = await _api.get<Map<String, dynamic>>('$_basePath/$id');
    return ProductModel.fromJson(body);
  }

  @override
  Future<ProductFeedPage> listFeed({
    int limit = kHomeFeedPageSize,
    int offset = 0,
    HomeFeedSort sort = HomeFeedSort.recommended,
    List<String> excludeIds = const [],
  }) {
    final query = <String, dynamic>{
      'sort': _feedSortParam(sort),
      'limit': limit,
      'offset': offset,
      if (excludeIds.isNotEmpty) 'exclude_id': excludeIds,
    };
    return _pageRequest(query);
  }

  @override
  Future<HomeForYouPage> fetchForYou({int limit = kHomeForYouLimit}) async {
    final body = await _api.get<Map<String, dynamic>>(
      '/catalog/home-feed',
      query: {'limit': limit},
      retries: 2,
    );
    final shelf = body['for_you'];
    final rows = shelf is Map ? shelf['rows'] : null;
    final items = rows is List
        ? rows
              .whereType<Map<String, dynamic>>()
              .map(ProductModel.fromJson)
              .toList(growable: false)
        : const <ProductModel>[];
    final personalized = body['personalized'] == true;
    return HomeForYouPage(items: items, personalized: personalized);
  }

  String _feedSortParam(HomeFeedSort sort) => switch (sort) {
    HomeFeedSort.recommended => 'recommended',
    HomeFeedSort.popular => 'popular',
    HomeFeedSort.discount => 'discount',
    HomeFeedSort.newest => 'newest',
  };

  @override
  Future<List<ProductModel>> search(
    String query, {
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = 30,
  }) async {
    final term = query.trim();
    if (term.isEmpty && filter.isDefault) return const [];
    final q = <String, dynamic>{
      if (term.isNotEmpty) 'search': term,
      ..._sortQuery(filter.sort),
      ..._facetQuery(filter),
      'limit': limit,
    };
    return _listRequest(q);
  }

  @override
  Future<List<ProductModel>> listSimilar(
    String productId, {
    int limit = 10,
  }) async {
    final body = await _api.get<List<dynamic>>(
      '$_basePath/$productId/similar',
      query: {'limit': limit},
    );
    return body
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList(growable: false);
  }

  Future<List<ProductModel>> _listRequest(Map<String, dynamic> query) async {
    final body = await _api.get<Map<String, dynamic>>(
      _basePath,
      query: _stringifyLists(query),
      retries: 2,
    );
    final rows = body['rows'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList(growable: false);
  }

  /// Paginated variant of [_listRequest] that also surfaces the catalog-wide
  /// `total`, so callers (home feed + category list infinite scroll) know when
  /// the last page has been reached. Falls back to `items.length` when the
  /// backend omits the total, treating a short page as the last one rather than
  /// looping forever.
  Future<ProductFeedPage> _pageRequest(Map<String, dynamic> query) async {
    final body = await _api.get<Map<String, dynamic>>(
      _basePath,
      query: _stringifyLists(query),
      retries: 2,
    );
    final rows = body['rows'];
    final items = rows is List
        ? rows
              .whereType<Map<String, dynamic>>()
              .map(ProductModel.fromJson)
              .toList(growable: false)
        : const <ProductModel>[];
    final total = (body['total'] as num?)?.toInt() ?? items.length;
    return ProductFeedPage(items: items, total: total);
  }

  /// Dio renders a `List` query value as repeated `?k=a&k=b` params only when
  /// the entries are strings, so coerce list values (e.g. multi-colour facet)
  /// before handing them over.
  Map<String, dynamic> _stringifyLists(Map<String, dynamic> query) {
    return query.map((k, v) {
      if (v is List) return MapEntry(k, v.map((e) => e.toString()).toList());
      return MapEntry(k, v);
    });
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
      if (filter.discountedOnly) 'discounted': true,
    };
  }
}
