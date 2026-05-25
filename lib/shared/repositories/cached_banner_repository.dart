import '../../core/logging/talker.dart';
import '../../core/storage/cache_store.dart';
import '../models/banner.dart';
import 'banner_repository.dart';

/// Cache-aside decorator over a [BannerRepository].
///
/// Home banners are marketing content that admins edit a few times a day at
/// most. A 6h TTL gives the home rail a 0 ms paint on cold start while still
/// rotating promotions in within a few hours.
///
/// Note: image bytes are cached separately by `CachedNetworkImage`; this
/// only caches the row metadata (title, link target, image URL). The two
/// caches compose — the banner row loads from Hive, the image loads from
/// the on-disk file cache, and the user sees a fully populated carousel
/// before the network is even touched.
class CachedBannerRepository extends BannerRepository {
  CachedBannerRepository({
    required BannerRepository inner,
    required CacheStore cache,
  }) : _inner = inner,
       _cache = cache;

  final BannerRepository _inner;
  final CacheStore _cache;

  static const String _key = 'banners:home';
  static const Duration _ttl = Duration(hours: 6);

  @override
  List<HomeBanner>? peek() {
    return _cache.getJson<List<HomeBanner>>(_key, (decoded) {
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => HomeBanner.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    });
  }

  @override
  Future<List<HomeBanner>> list() async {
    try {
      final fresh = await _inner.list();
      _cache.putJson(_key, fresh.map((b) => b.toJson()).toList(), ttl: _ttl);
      return fresh;
    } catch (e, st) {
      final cached = peek();
      if (cached != null && cached.isNotEmpty) {
        talker.handle(
          e,
          st,
          'CachedBannerRepository: network failed, '
          'serving ${cached.length} cached banners',
        );
        return cached;
      }
      rethrow;
    }
  }
}
