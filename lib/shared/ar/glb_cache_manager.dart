import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Dedicated on-disk file cache for buyer 3D models (`.glb`). Kept SEPARATE
/// from the `CachedNetworkImage` image cache (`DefaultCacheManager`) so the
/// (multi-MB) model files have their own eviction budget and never starve the
/// image cache — and so clearing one can't drop the other.
///
/// Large binary models are NEVER stored in Hive or held in memory: they live on
/// the file system and are streamed into `<model-viewer>` straight from a
/// `file://` path. [maxNrOfCacheObjects] caps how many models survive so the
/// app can't grow an unbounded model store — the least-recently-used `.glb`s
/// are auto-purged once the cap is hit, and anything older than [stalePeriod]
/// is re-fetched on next use.
class GlbCacheManager {
  GlbCacheManager._();

  /// Unique store key — two `CacheManager`s sharing a key is a runtime error,
  /// so this string must differ from `DefaultCacheManager`'s `libCachedImageData`.
  static const String key = 'woody_glb_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      // A model rarely changes once QC-approved, so a long stale window keeps
      // switching instant across sessions; an updated model still refreshes
      // within two weeks.
      stalePeriod: const Duration(days: 14),
      // ~ a handful of full furniture sets. Oldest models evict first (LRU),
      // bounding disk use so a heavy browsing session can't balloon storage.
      maxNrOfCacheObjects: 24,
    ),
  );
}

/// Narrow seam the 3D viewer uses to turn a remote `.glb` URL into a local
/// `file://` source `<model-viewer>` can read off disk with zero network
/// round-trip. Every method is best-effort and NEVER throws: on any cache
/// failure it falls back to the original remote URL so the viewer degrades to
/// streaming rather than dead-ending.
class GlbCacheService {
  GlbCacheService({CacheManager? manager}) : _manager = manager;

  final CacheManager? _manager;

  /// Resolved lazily so a test subclass that overrides [peek]/[resolve] never
  /// forces the real [GlbCacheManager] (whose `Config` eagerly opens the OS
  /// cache directory via `path_provider`, unavailable in unit tests).
  CacheManager get _cache => _manager ?? GlbCacheManager.instance;

  /// Ceiling on a single model download so a stalled connection can't pin the
  /// viewer on its "downloading" overlay — past this we fall back to streaming
  /// the remote URL (which has its own load watchdog in the viewer).
  static const Duration _downloadTimeout = Duration(seconds: 20);

  /// A `file://` source if [url] is already on disk AND still fresh, else null.
  /// Lets the viewer switch to a cached part instantly with no "downloading"
  /// flash. An expired entry (past the manager's `stalePeriod`) is reported as a
  /// miss so [resolve] re-downloads it — otherwise a stale model would render
  /// forever, since `peek` (unlike `getSingleFile`) never re-fetches. Never
  /// throws — a missing/half-written entry simply reads as "not cached".
  ///
  /// The returned `file://` URI is read back by the model_viewer_plus proxy via
  /// the raw `Uri.path`, so it only round-trips for percent-encoding-free paths.
  /// That holds here: the store key + hashed filenames are ASCII and the OS
  /// cache dir has no spaces — a remote `.glb` is never served by its raw URL.
  Future<String?> peek(String url) async {
    if (url.isEmpty) return null;
    try {
      final info = await _cache.getFileFromCache(url);
      final file = info?.file;
      if (info != null &&
          info.validTill.isAfter(DateTime.now()) &&
          await file!.exists()) {
        return Uri.file(file.path).toString();
      }
    } catch (_) {
      // Treat any cache-store error as a clean miss.
    }
    return null;
  }

  /// A `file://` source for [url], downloading + caching it first if needed.
  /// Falls back to the original remote [url] on any failure so the caller still
  /// gets a usable source (model-viewer then streams it directly). Never throws.
  Future<String> resolve(String url) async {
    if (url.isEmpty) return url;
    try {
      final file = await _cache.getSingleFile(url).timeout(_downloadTimeout);
      if (await file.exists()) {
        return Uri.file(file.path).toString();
      }
    } catch (_) {
      // Timeout/network/disk failure → stream from the network URL as a
      // fallback. On a >timeout slow link the underlying download is left
      // running so it still warms the cache for next time; streaming the URL
      // now is a deliberate, bounded one-off duplicate fetch rather than
      // pinning the viewer on its loading overlay.
    }
    return url;
  }
}
