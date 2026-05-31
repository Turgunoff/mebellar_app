
import '../models/banner.dart';

abstract class BannerRepository {
  Future<List<HomeBanner>> list();

  /// Synchronous read of any cached snapshot. Returns `null` on a cache miss
  /// or for non-caching implementations. Blocs use this to hydrate state on
  /// cold start before the network call lands.
  List<HomeBanner>? peek() => null;
}
