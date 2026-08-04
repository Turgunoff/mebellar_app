import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../analytics/analytics_privacy.dart';
import '../auth/auth_repository.dart';
import '../logging/app_logger.dart';
import '../network/woody_api_client.dart';

/// Lag-safe signed-in presence → `POST /me/presence`.
///
/// Rules: privacy gate, signed-in only, ≤1 ping / 5 min, 3s timeout,
/// never await from UI — callers use [onResumed] / [ping] fire-and-forget.
class PresenceService {
  PresenceService({
    required WoodyApiClient api,
    required AuthRepository auth,
    required Box settingsBox,
  }) : _api = api,
       _auth = auth,
       _settingsBox = settingsBox;

  final WoodyApiClient _api;
  final AuthRepository _auth;
  final Box _settingsBox;

  static const Duration debounce = Duration(minutes: 5);
  static const Duration requestTimeout = Duration(seconds: 3);

  DateTime? _lastSentAt;
  Timer? _foregroundTimer;
  Map<String, String>? _cachedMeta;
  Future<void>? _warmInFlight;

  /// Device / OS / app fields for FCM register + presence (cached).
  Map<String, String>? get cachedMeta => _cachedMeta;

  Future<void> warmCache() {
    return _warmInFlight ??= _warmCacheBody();
  }

  Future<void> _warmCacheBody() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final plugin = DeviceInfoPlugin();
      String? model;
      late final String os;
      String? osVersion;
      if (kIsWeb) {
        os = 'web';
      } else if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        model = info.model;
        os = 'android';
        osVersion = info.version.release;
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        model = info.utsname.machine;
        os = 'ios';
        osVersion = info.systemVersion;
      } else {
        os = Platform.operatingSystem;
        osVersion = Platform.operatingSystemVersion;
      }
      _cachedMeta = {
        if (model != null && model.isNotEmpty) 'device_model': model,
        'os': os,
        if (osVersion != null && osVersion.isNotEmpty) 'os_version': osVersion,
        'app_version': '${package.version}+${package.buildNumber}',
      };
    } catch (e, st) {
      appLog.handle(e, st, 'PresenceService.warmCache failed');
      _cachedMeta ??= {};
    } finally {
      _warmInFlight = null;
    }
  }

  /// Foreground only — recreates the periodic Timer after any background cancel.
  void onResumed() {
    startForegroundLoop();
    unawaited(ping());
  }

  /// Call on [AppLifecycleState.paused] / [hidden] / [inactive] — cancels Timer.
  void onPaused() {
    stop();
  }

  void startForegroundLoop() {
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(debounce, (_) {
      unawaited(ping());
    });
  }

  void stop() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
  }

  /// Fire-and-forget safe; swallows errors.
  Future<void> ping() async {
    if (!readAnalyticsCollectionEnabled(_settingsBox)) return;
    if (_auth.currentUserId == null) return;

    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!) < debounce) {
      return;
    }

    if (_cachedMeta == null) {
      await warmCache();
    }
    _lastSentAt = now;

    try {
      await _api
          .post<dynamic>('/me/presence', body: _cachedMeta ?? const {})
          .timeout(requestTimeout);
    } catch (e, st) {
      appLog.handle(e, st, 'PresenceService.ping failed');
    }
  }
}
