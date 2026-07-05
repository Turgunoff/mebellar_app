import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/logging/app_logger.dart';
import 'glb_cache_manager.dart';

/// iOS AR Quick Look launcher. WKWebView's `<model-viewer>` reports
/// `canActivateAR == false` even when a valid `.usdz` is present, so native
/// Quick Look is the reliable path on iOS.
class IosQuickLookLauncher {
  IosQuickLookLauncher._();

  static const MethodChannel _channel = MethodChannel('com.mebellar.app/ar');

  /// Opens [usdzUrl] in AR Quick Look. Remote `https` URLs are cached to a
  /// local file first — Quick Look does not load network USDZ reliably.
  static Future<bool> launch(String? usdzUrl, {GlbCacheService? cache}) async {
    if (!Platform.isIOS) return false;
    final url = usdzUrl?.trim();
    if (url == null || url.isEmpty) return false;

    final path = await _localPath(url, cache: cache);
    if (path == null) return false;

    final quickLookPath = await _ensureUsdzExtension(path);
    if (quickLookPath == null) return false;

    try {
      final ok = await _channel.invokeMethod<bool>('launchQuickLook', {
        'path': quickLookPath,
      });
      return ok ?? false;
    } catch (e, st) {
      appLog.handle(e, st, '[ios-quick-look] launch failed');
      return false;
    }
  }

  static Future<String?> _localPath(
    String url, {
    GlbCacheService? cache,
  }) async {
    if (url.startsWith('file://')) {
      return Uri.parse(url).toFilePath();
    }
    if (url.startsWith('http')) {
      final resolved = await (cache ?? GlbCacheService()).resolve(url);
      if (resolved.startsWith('file://')) {
        return Uri.parse(resolved).toFilePath();
      }
    }
    return null;
  }

  /// Quick Look identifies USDZ by the `.usdz` extension. [GlbCacheService]
  /// stores downloads via `flutter_cache_manager`, which maps the
  /// `model/vnd.usdz+zip` Content-Type to a `.vnd` (or `.vnd.usdz+zip`) suffix —
  /// valid bytes, wrong name, so QL shows a generic "data" preview instead of AR.
  static Future<String?> _ensureUsdzExtension(String path) async {
    if (path.toLowerCase().endsWith('.usdz')) return path;

    final src = File(path);
    if (!await src.exists()) return null;

    try {
      final dest = File(
        '${src.parent.path}/woody_ar_${src.path.hashCode.abs()}.usdz',
      );
      if (!await dest.exists()) {
        await src.copy(dest.path);
      }
      return dest.path;
    } catch (e, st) {
      appLog.handle(e, st, '[ios-quick-look] usdz extension fix failed');
      return null;
    }
  }

  /// Test seam for [localPath] resolution without invoking the method channel.
  @visibleForTesting
  static Future<String?> localPathForTest(
    String url, {
    GlbCacheService? cache,
  }) => _localPath(url, cache: cache);

  /// Test seam for [_ensureUsdzExtension].
  @visibleForTesting
  static Future<String?> ensureUsdzExtensionForTest(String path) =>
      _ensureUsdzExtension(path);
}
