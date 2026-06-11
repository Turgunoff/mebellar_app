import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Narrowly-scoped seam over the app's *disposable* caches:
///   - the on-disk file cache behind `CachedNetworkImage`
///     (`flutter_cache_manager`),
///   - the in-memory decoded-bitmap LRU (`PaintingBinding.imageCache`),
///   - leftover scratch files in the OS temporary directory.
///
/// **Safety invariant:** this type has NO reference to `flutter_secure_storage`,
/// the token store, or any Hive box. Clearing the cache must never be able to
/// sign the user out or drop their settings — those live in the Keychain/
/// Keystore and the app-documents directory, neither of which is touched here.
abstract class CacheService {
  /// Combined byte size of the disposable on-disk caches. Best-effort: returns
  /// what it can read and never throws.
  Future<int> sizeBytes();

  /// Wipes the disposable caches (see class doc). Best-effort and idempotent.
  Future<void> clear();
}

class DefaultCacheService implements CacheService {
  const DefaultCacheService();

  @override
  Future<int> sizeBytes() async {
    try {
      final tmp = await getTemporaryDirectory();
      return _directorySize(tmp);
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> clear() async {
    // 1. On-disk file cache backing CachedNetworkImage.
    await DefaultCacheManager().emptyCache();

    // 2. In-memory decoded-bitmap LRU + currently-live images.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();

    // 3. Remaining scratch files in the OS temp/cache dir. This directory is
    //    disposable by definition; secure storage (Keychain/Keystore) and the
    //    Hive boxes (app-documents dir) live elsewhere and are NOT touched.
    try {
      final tmp = await getTemporaryDirectory();
      if (tmp.existsSync()) {
        await for (final entity in tmp.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {
            // Busy/locked file — skip it, best-effort.
          }
        }
      }
    } catch (_) {
      // No temp dir / platform without one — nothing to do.
    }
  }

  static Future<int> _directorySize(Directory dir) async {
    if (!dir.existsSync()) return 0;
    var total = 0;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            // Vanished mid-walk — ignore.
          }
        }
      }
    } catch (_) {
      // Unreadable dir — return whatever we summed so far.
    }
    return total;
  }
}
