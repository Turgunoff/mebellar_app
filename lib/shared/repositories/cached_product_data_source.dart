import '../../core/logging/talker.dart';
import '../../core/storage/cache_store.dart';
import '../models/supabase_product_model.dart';
import 'supabase_product_data_source.dart';

/// Cache-aside decorator over a [SupabaseProductDataSource].
///
/// Caches a deliberately narrow set of the read methods — only the calls
/// where the cache key space is bounded and re-visit probability is high:
///
///   * [listAll] — the home recommended rail. One key, fixed limit. High
///     re-visit on every cold start.
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
/// edits immediately because the seller surfaces hit Supabase directly via
/// the seller-side product repos — this decorator only wraps the customer
/// catalogue data source.
class CachedProductDataSource extends SupabaseProductDataSource {
  CachedProductDataSource({
    required SupabaseProductDataSource inner,
    required CacheStore cache,
  }) : _inner = inner,
       _cache = cache;

  final SupabaseProductDataSource _inner;
  final CacheStore _cache;

  // Key prefixes — namespaced so a future `invalidate('products:')` call
  // wipes every product-shaped row in one pass without touching banners /
  // categories.
  static const String _kRecommended = 'products:recommended:';
  static const String _kById = 'products:byId:';
  static const String _kSimilar = 'products:similar:';
  static const String _kByCategory = 'products:byCategory:';

  static const Duration _ttlRecommended = Duration(hours: 1);
  static const Duration _ttlById = Duration(hours: 4);
  static const Duration _ttlSimilar = Duration(hours: 4);
  // Category listings are 1h: stock + price churn is per-product, so a
  // multi-product page goes stale faster than a single product detail.
  static const Duration _ttlByCategory = Duration(hours: 1);

  SupabaseProductModel? _decodeOne(dynamic decoded) {
    if (decoded is! Map) return null;
    return SupabaseProductModel.fromJson(Map<String, dynamic>.from(decoded));
  }

  List<SupabaseProductModel> _decodeList(dynamic decoded) {
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => SupabaseProductModel.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  @override
  List<SupabaseProductModel>? peekRecommended() {
    // The bloc only ever requests the default limit (10), so we don't bother
    // varying the key by limit — saves duplicating identical pages.
    return _cache.getJson<List<SupabaseProductModel>>(
      '${_kRecommended}10',
      _decodeList,
    );
  }

  @override
  SupabaseProductModel? peekById(String id) {
    return _cache.getJson<SupabaseProductModel?>('$_kById$id', _decodeOne);
  }

  @override
  List<SupabaseProductModel>? peekByCategory(String categoryId) {
    return _cache.getJson<List<SupabaseProductModel>>(
      '$_kByCategory$categoryId',
      _decodeList,
    );
  }

  @override
  List<SupabaseProductModel>? peekSimilar(String productId, {int limit = 10}) {
    return _cache.getJson<List<SupabaseProductModel>>(
      '$_kSimilar$productId:$limit',
      _decodeList,
    );
  }

  @override
  Future<List<SupabaseProductModel>> listAll({int limit = 10}) async {
    final key = '$_kRecommended$limit';
    try {
      final fresh = await _inner.listAll(limit: limit);
      _cache.putJson(
        key,
        fresh.map((p) => p.toJson()).toList(),
        ttl: _ttlRecommended,
      );
      return fresh;
    } catch (e, st) {
      final cached = _cache.getJson<List<SupabaseProductModel>>(
        key,
        _decodeList,
      );
      if (cached != null && cached.isNotEmpty) {
        talker.handle(
          e,
          st,
          'CachedProductDataSource.listAll: network '
          'failed, serving ${cached.length} cached items',
        );
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<SupabaseProductModel> getById(String id) async {
    final key = '$_kById$id';
    try {
      final fresh = await _inner.getById(id);
      _cache.putJson(key, fresh.toJson(), ttl: _ttlById);
      return fresh;
    } catch (e, st) {
      final cached = _cache.getJson<SupabaseProductModel?>(key, _decodeOne);
      if (cached != null) {
        talker.handle(
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
  Future<List<SupabaseProductModel>> listSimilar(
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
      final cached = _cache.getJson<List<SupabaseProductModel>>(
        key,
        _decodeList,
      );
      if (cached != null && cached.isNotEmpty) {
        talker.handle(
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
  Future<List<SupabaseProductModel>> listByCategory({
    required String categoryId,
    String? subcategoryId,
    ProductSearchFilter filter = const ProductSearchFilter(),
  }) async {
    // Only the "tap-and-browse" entry point is cacheable — once the user
    // narrows by subcategory chip or any filter facet, we fall through to
    // the network. That keeps cache keys to one per category instead of one
    // per (category × subcategory × filter × sort) combination.
    final cacheable = subcategoryId == null && filter.isDefault;
    if (!cacheable) {
      return _inner.listByCategory(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        filter: filter,
      );
    }

    final key = '$_kByCategory$categoryId';
    try {
      final fresh = await _inner.listByCategory(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        filter: filter,
      );
      _cache.putJson(
        key,
        fresh.map((p) => p.toJson()).toList(),
        ttl: _ttlByCategory,
      );
      return fresh;
    } catch (e, st) {
      final cached = _cache.getJson<List<SupabaseProductModel>>(
        key,
        _decodeList,
      );
      if (cached != null && cached.isNotEmpty) {
        talker.handle(
          e,
          st,
          'CachedProductDataSource.listByCategory($categoryId): network '
          'failed, serving ${cached.length} cached items',
        );
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<SupabaseProductModel>> listBySubcategory({
    required String subcategoryId,
  }) => _inner.listBySubcategory(subcategoryId: subcategoryId);

  @override
  Future<List<SupabaseProductModel>> search(
    String query, {
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = 30,
  }) => _inner.search(query, filter: filter, limit: limit);
}
