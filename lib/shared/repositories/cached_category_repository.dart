import '../../core/logging/talker.dart';
import '../../core/storage/cache_store.dart';
import '../models/category_model.dart';
import 'supabase_category_repository.dart';

/// Cache-aside decorator over a [CategoryDataSource].
///
/// Categories are static reference data — they change at the speed of an
/// admin updating the catalogue, not at the speed of a shopper browsing.
/// Caching for 24h lets the home shell render instantly on every cold start
/// while still picking up admin edits within a day.
///
/// Two behaviours that matter:
///   * [peek] is synchronous and lets the bloc hydrate state on cold start
///     before any network RTT — the categories rail paints at 0 ms.
///   * [list] is write-through: a successful fetch refreshes the cache, and
///     a network failure falls back to the cached snapshot if one exists,
///     so a flaky connection never blanks the home screen.
class CachedCategoryRepository extends CategoryDataSource {
  CachedCategoryRepository({
    required CategoryDataSource inner,
    required CacheStore cache,
  }) : _inner = inner,
       _cache = cache;

  final CategoryDataSource _inner;
  final CacheStore _cache;

  static const String _key = 'categories:tree';
  static const Duration _ttl = Duration(hours: 24);

  @override
  List<CategoryModel>? peek() {
    return _cache.getJson<List<CategoryModel>>(_key, (decoded) {
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => CategoryModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    });
  }

  @override
  Future<List<CategoryModel>> list() async {
    try {
      final fresh = await _inner.list();
      _cache.putJson(_key, fresh.map((c) => c.toJson()).toList(), ttl: _ttl);
      return fresh;
    } catch (e, st) {
      final cached = peek();
      if (cached != null && cached.isNotEmpty) {
        talker.handle(
          e,
          st,
          'CachedCategoryRepository: network failed, '
          'serving ${cached.length} cached categories',
        );
        return cached;
      }
      rethrow;
    }
  }
}
