import '../../core/logging/app_logger.dart';
import '../../core/storage/cache_store.dart';
import '../models/product_model.dart';
import 'product_data_source.dart';

/// Cache-aside decorator over a [ProductDataSource].
///
/// Caches a deliberately narrow set of the read methods — only the calls
/// where the cache key space is bounded and re-visit probability is high:
///
///   * [listFeed] — the home trending feed's first page (offset 0, recommended sort).
///   * [fetchForYou] — guest for-you shelf only (`personalized: false`).
///   * [getById] — single product detail. Bounded by product count. Hit on
///     deep-link, cart→detail navigation, favourites→detail.
///   * [listSimilar] — sibling carousel on the detail page. Bounded by
///     product count. Hit on every detail open.
///   * [listByCategory] — but ONLY when the call is fully default (no
///     subcategory, no facets, default sort). This is the "tap a category
///     from the home grid → see all products" flow, which is overwhelmingly
///     the most common entry point. Once the user touches a filter the call
///     falls through to the network (see class doc on key explosion).
///
/// Deliberately NOT cached: [search] and any filtered/sorted
/// [listByCategory]. Their parameter surface (free-text query × filter
/// facets × sort) explodes the key space, and the resulting cached pages
/// would mostly never be re-read.
///
/// All TTLs are conservative: products are mutable (price, stock, discount,
/// images), so we cap staleness to a few hours. Sellers see their own
/// edits immediately because the seller surfaces hit the backend directly via
/// the seller-side product repos — this decorator only wraps the customer
/// catalogue data source.
class CachedProductDataSource extends ProductDataSource {
  CachedProductDataSource({
    required ProductDataSource inner,
    required CacheStore cache,
  }) : _inner = inner,
       _cache = cache;

  final ProductDataSource _inner;
  final CacheStore _cache;

  // Key prefixes — namespaced so a future `invalidate('products:')` call
  // wipes every product-shaped row in one pass without touching banners /
  // categories.
  static const String _kFeed = 'products:recommended:';
  static const String _kForYou = 'products:forYou:';
  static const String _kById = 'products:byId:';
  static const String _kSimilar = 'products:similar:';
  static const String _kByCategory = 'products:byCategory:';

  static const Duration _ttlFeed = Duration(hours: 1);
  static const Duration _ttlForYou = Duration(hours: 1);
  static const Duration _ttlById = Duration(hours: 4);
  static const Duration _ttlSimilar = Duration(hours: 4);
  // Category listings are 1h: stock + price churn is per-product, so a
  // multi-product page goes stale faster than a single product detail.
  static const Duration _ttlByCategory = Duration(hours: 1);

  ProductModel? _decodeOne(dynamic decoded) {
    if (decoded is! Map) return null;
    return ProductModel.fromJson(Map<String, dynamic>.from(decoded));
  }

  List<ProductModel> _decodeList(dynamic decoded) {
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => ProductModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  ProductFeedPage? _decodeFeed(dynamic decoded) {
    if (decoded is! Map) return null;
    final items = decoded['items'];
    if (items is! List) return null;
    final products = items
        .whereType<Map>()
        .map((m) => ProductModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
    final total = (decoded['total'] as num?)?.toInt() ?? products.length;
    return ProductFeedPage(items: products, total: total);
  }

  HomeForYouPage? _decodeForYou(dynamic decoded) {
    if (decoded is! Map) return null;
    final items = decoded['items'];
    if (items is! List) return null;
    final products = items
        .whereType<Map>()
        .map((m) => ProductModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
    final personalized = decoded['personalized'] == true;
    return HomeForYouPage(items: products, personalized: personalized);
  }

  @override
  ProductFeedPage? peekFeed() {
    return _cache.getJson<ProductFeedPage?>(
      '$_kFeed$kHomeFeedPageSize',
      _decodeFeed,
    );
  }

  @override
  HomeForYouPage? peekForYou() {
    return _cache.getJson<HomeForYouPage?>(
      '$_kForYou$kHomeForYouLimit',
      _decodeForYou,
    );
  }

  @override
  ProductModel? peekById(String id) {
    return _cache.getJson<ProductModel?>('$_kById$id', _decodeOne);
  }

  @override
  ProductFeedPage? peekByCategory(String categoryId) {
    // One entry per category covers the cold-start paint — the cubit always
    // requests the first page at [kCategoryPageSize] for the default view.
    return _cache.getJson<ProductFeedPage?>(
      '$_kByCategory$categoryId',
      _decodeFeed,
    );
  }

  @override
  List<ProductModel>? peekSimilar(String productId, {int limit = 10}) {
    return _cache.getJson<List<ProductModel>>(
      '$_kSimilar$productId:$limit',
      _decodeList,
    );
  }

  @override
  Future<ProductFeedPage> listFeed({
    int limit = kHomeFeedPageSize,
    int offset = 0,
    HomeFeedSort sort = HomeFeedSort.recommended,
    List<String> excludeIds = const [],
  }) async {
    final cacheable =
        offset == 0 && sort == HomeFeedSort.recommended && excludeIds.isEmpty;
    if (!cacheable) {
      return _inner.listFeed(
        limit: limit,
        offset: offset,
        sort: sort,
        excludeIds: excludeIds,
      );
    }

    final key = '$_kFeed$limit';
    try {
      final fresh = await _inner.listFeed(
        limit: limit,
        offset: offset,
        sort: sort,
        excludeIds: excludeIds,
      );
      _cache.putJson(key, {
        'items': fresh.items.map((p) => p.toJson()).toList(),
        'total': fresh.total,
      }, ttl: _ttlFeed);
      return fresh;
    } catch (e, st) {
      final cached = _cache.getJson<ProductFeedPage?>(key, _decodeFeed);
      if (cached != null && cached.items.isNotEmpty) {
        appLog.handle(
          e,
          st,
          'CachedProductDataSource.listFeed: network '
          'failed, serving ${cached.items.length} cached items',
        );
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<HomeForYouPage> fetchForYou({int limit = kHomeForYouLimit}) async {
    try {
      final fresh = await _inner.fetchForYou(limit: limit);
      if (!fresh.personalized) {
        _cache.putJson('$_kForYou$limit', {
          'items': fresh.items.map((p) => p.toJson()).toList(),
          'personalized': fresh.personalized,
        }, ttl: _ttlForYou);
      }
      return fresh;
    } catch (e, st) {
      final cached = _cache.getJson<HomeForYouPage?>(
        '$_kForYou$limit',
        _decodeForYou,
      );
      if (cached != null && cached.items.isNotEmpty) {
        appLog.handle(
          e,
          st,
          'CachedProductDataSource.fetchForYou: network '
          'failed, serving ${cached.items.length} cached items',
        );
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<ProductModel> getById(String id) async {
    final key = '$_kById$id';
    try {
      final fresh = await _inner.getById(id);
      _cache.putJson(key, fresh.toJson(), ttl: _ttlById);
      return fresh;
    } catch (e, st) {
      final cached = _cache.getJson<ProductModel?>(key, _decodeOne);
      if (cached != null) {
        appLog.handle(
          e,
          st,
          'CachedProductDataSource.getById($id): network '
          'failed, serving cached product',
        );
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<ProductModel>> listSimilar(
    String productId, {
    int limit = 10,
  }) async {
    final key = '$_kSimilar$productId:$limit';
    try {
      final fresh = await _inner.listSimilar(productId, limit: limit);
      _cache.putJson(
        key,
        fresh.map((p) => p.toJson()).toList(),
        ttl: _ttlSimilar,
      );
      return fresh;
    } catch (e, st) {
      final cached = _cache.getJson<List<ProductModel>>(key, _decodeList);
      if (cached != null && cached.isNotEmpty) {
        appLog.handle(
          e,
          st,
          'CachedProductDataSource.listSimilar('
          '$productId): network failed, serving cached',
        );
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<ProductFeedPage> listByCategory({
    required String categoryId,
    String? subcategoryId,
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = kCategoryPageSize,
    int offset = 0,
  }) async {
    // Only the FIRST page of the "tap-and-browse" entry point is cacheable —
    // that's the cold-start paint. Once the user narrows by subcategory chip
    // or any filter facet, OR scrolls past page one, we fall through to the
    // network. That keeps cache keys to one per category instead of one per
    // (category × subcategory × filter × sort × page).
    final cacheable = subcategoryId == null && filter.isDefault && offset == 0;
    if (!cacheable) {
      return _inner.listByCategory(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        filter: filter,
        limit: limit,
        offset: offset,
      );
    }

    final key = '$_kByCategory$categoryId';
    try {
      final fresh = await _inner.listByCategory(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        filter: filter,
        limit: limit,
        offset: offset,
      );
      _cache.putJson(key, {
        'items': fresh.items.map((p) => p.toJson()).toList(),
        'total': fresh.total,
      }, ttl: _ttlByCategory);
      return fresh;
    } catch (e, st) {
      final cached = _cache.getJson<ProductFeedPage?>(key, _decodeFeed);
      if (cached != null && cached.items.isNotEmpty) {
        appLog.handle(
          e,
          st,
          'CachedProductDataSource.listByCategory($categoryId): network '
          'failed, serving ${cached.items.length} cached items',
        );
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<ProductModel>> listBySubcategory({
    required String subcategoryId,
  }) => _inner.listBySubcategory(subcategoryId: subcategoryId);

  @override
  Future<List<ProductModel>> search(
    String query, {
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = 30,
  }) => _inner.search(query, filter: filter, limit: limit);
}
