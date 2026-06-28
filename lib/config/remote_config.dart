import 'package:hive_flutter/hive_flutter.dart';

import '../core/logging/app_logger.dart';
import '../core/network/api_error.dart';
import '../core/network/woody_api_client.dart';

/// Runtime feature flags sourced from the woody_backend `app_settings` table
/// via the public `GET /catalog/settings/{key}` endpoint.
///
/// Unlike [AppConfig] (compile-time env), these can be flipped server-side
/// without shipping a new build. The value is hydrated synchronously from the
/// Hive `settings` box (offline-safe, instant) and refreshed from the network
/// in the background — a failed or pending fetch keeps the last cached value,
/// or `false` on a first launch, so tariff stays *off* rather than wrongly
/// gating sellers behind a paywall.
///
/// Read synchronously anywhere via [RemoteConfig.instance].
class RemoteConfig {
  RemoteConfig._();

  static final RemoteConfig instance = RemoteConfig._();

  /// Master switch for the tariff / subscription system. When `false` the app
  /// hides every tariff surface and product creation is unlimited. Mirrors the
  /// DB `app_settings.tariff_enabled` flag, which the quota triggers also gate
  /// on — so the app and the database agree.
  bool tariffEnabled = false;

  /// Force-update threshold for Android, e.g. `"1.0.3"`. An installed version
  /// below this triggers the blocking force-update overlay. `null` (key missing
  /// server-side or never fetched) means nothing is forced.
  String? androidMinVersion;

  /// Force-update threshold for iOS, e.g. `"1.0.3"`. Same semantics as
  /// [androidMinVersion] — the stores release on independent cadences, so each
  /// platform carries its own threshold.
  String? iosMinVersion;

  /// When `true` the whole app is frozen behind a blocking maintenance overlay
  /// (checked BEFORE the force-update gate). Mirrors `app_settings.maintenance`.
  bool maintenanceEnabled = false;

  /// Customer-facing maintenance copy, set by the operator. Empty until fetched;
  /// the overlay falls back to a localized default when blank.
  String maintenanceMessage = '';

  static const _tariffHiveKey = 'remote_config.tariff_enabled';
  static const _androidMinVersionHiveKey =
      'remote_config.android_min_version';
  static const _iosMinVersionHiveKey = 'remote_config.ios_min_version';
  static const _maintenanceEnabledHiveKey = 'remote_config.maintenance_enabled';
  static const _maintenanceMessageHiveKey = 'remote_config.maintenance_message';

  /// Seeds the flags from the last cached values. Synchronous, so it can run
  /// at boot before the first frame.
  void hydrateFromCache(Box box) {
    final cached = box.get(_tariffHiveKey);
    if (cached is bool) tariffEnabled = cached;
    final androidMin = box.get(_androidMinVersionHiveKey);
    if (androidMin is String && androidMin.isNotEmpty) {
      androidMinVersion = androidMin;
    }
    final iosMin = box.get(_iosMinVersionHiveKey);
    if (iosMin is String && iosMin.isNotEmpty) iosMinVersion = iosMin;
    final maint = box.get(_maintenanceEnabledHiveKey);
    if (maint is bool) maintenanceEnabled = maint;
    final maintMsg = box.get(_maintenanceMessageHiveKey);
    if (maintMsg is String) maintenanceMessage = maintMsg;
  }

  Future<void>? _inflightRefresh;

  /// Completes when the in-flight [refresh] does (or immediately when none is
  /// running). The update gate awaits this so a min_version bumped server-side
  /// takes effect on the very launch that fetched it, not the next one.
  Future<void> get whenRefreshed => _inflightRefresh ?? Future.value();

  /// Re-fetches every flag from `GET /catalog/settings/{key}`. Best-effort:
  /// on any failure the cached/default value is kept, so boot is never
  /// blocked on the network. A 404 means the key isn't configured
  /// server-side — tariff is treated as *disabled*, versions as *unset*.
  Future<void> refresh(WoodyApiClient api, Box box) {
    final work = Future.wait([
      _refreshTariff(api, box),
      _refreshAppVersions(api, box),
      _refreshMaintenance(api, box),
    ]).then((_) {});
    _inflightRefresh = work;
    return work;
  }

  Future<void> _refreshTariff(WoodyApiClient api, Box box) async {
    try {
      final body = await api
          .get<Map<String, dynamic>>('/catalog/settings/tariff_enabled')
          .timeout(const Duration(seconds: 6));
      // `value` is the jsonb column — a boolean, but tolerate 'true' too.
      final value = body['value'];
      tariffEnabled = value == true || value == 'true';
      await box.put(_tariffHiveKey, tariffEnabled);
      appLog.info('[remote-config] tariff_enabled=$tariffEnabled');
    } on ApiError catch (e, st) {
      if (e.isNotFound) {
        tariffEnabled = false;
        await box.put(_tariffHiveKey, false);
        return;
      }
      appLog.handle(
        e,
        st,
        '[remote-config] refresh failed — kept cached value',
      );
    } catch (e, st) {
      appLog.handle(
        e,
        st,
        '[remote-config] refresh failed — kept cached value',
      );
    }
  }

  Future<void> _refreshAppVersions(WoodyApiClient api, Box box) async {
    try {
      final body = await api
          .get<Map<String, dynamic>>('/catalog/settings/app_versions')
          .timeout(const Duration(seconds: 6));
      final (:androidMin, :iosMin) = parseMinVersions(body['value']);
      androidMinVersion = androidMin;
      iosMinVersion = iosMin;
      await box.put(_androidMinVersionHiveKey, androidMin ?? '');
      await box.put(_iosMinVersionHiveKey, iosMin ?? '');
      appLog.info('[remote-config] min android=$androidMin ios=$iosMin');
    } on ApiError catch (e, st) {
      if (e.isNotFound) {
        androidMinVersion = null;
        iosMinVersion = null;
        await box.put(_androidMinVersionHiveKey, '');
        await box.put(_iosMinVersionHiveKey, '');
        return;
      }
      appLog.handle(
        e,
        st,
        '[remote-config] app_versions refresh failed — kept cached value',
      );
    } catch (e, st) {
      appLog.handle(
        e,
        st,
        '[remote-config] app_versions refresh failed — kept cached value',
      );
    }
  }

  /// Extracts each platform's `min_version` from the `app_versions` jsonb value:
  /// `{"android": {"min_version": "1.0.0", ...}, "ios": {"min_version": ...}}`.
  /// Defensive against partial / malformed payloads — a missing or non-string
  /// field reads as `null` rather than throwing during boot.
  static ({String? androidMin, String? iosMin}) parseMinVersions(
    dynamic value,
  ) {
    String? minOf(dynamic block) {
      if (block is! Map) return null;
      final v = block['min_version'];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    if (value is! Map) return (androidMin: null, iosMin: null);
    return (
      androidMin: minOf(value['android']),
      iosMin: minOf(value['ios']),
    );
  }

  Future<void> _refreshMaintenance(WoodyApiClient api, Box box) async {
    try {
      final body = await api
          .get<Map<String, dynamic>>('/catalog/settings/maintenance')
          .timeout(const Duration(seconds: 6));
      final (:enabled, :message) = parseMaintenance(body['value']);
      maintenanceEnabled = enabled;
      maintenanceMessage = message;
      await box.put(_maintenanceEnabledHiveKey, enabled);
      await box.put(_maintenanceMessageHiveKey, message);
      appLog.info('[remote-config] maintenance=$enabled');
    } on ApiError catch (e, st) {
      if (e.isNotFound) {
        maintenanceEnabled = false;
        maintenanceMessage = '';
        await box.put(_maintenanceEnabledHiveKey, false);
        await box.put(_maintenanceMessageHiveKey, '');
        return;
      }
      appLog.handle(
        e,
        st,
        '[remote-config] maintenance refresh failed — kept cached value',
      );
    } catch (e, st) {
      appLog.handle(
        e,
        st,
        '[remote-config] maintenance refresh failed — kept cached value',
      );
    }
  }

  /// Extracts `(enabled, message)` from the `maintenance` jsonb value:
  /// `{"enabled": true, "message": "..."}`. Defensive — anything unexpected
  /// reads as *disabled* with an empty message rather than throwing at boot.
  static ({bool enabled, String message}) parseMaintenance(dynamic value) {
    if (value is! Map) return (enabled: false, message: '');
    final raw = value['enabled'];
    final enabled = raw == true || raw == 'true';
    final msg = value['message'];
    return (
      enabled: enabled,
      message: msg is String ? msg.trim() : '',
    );
  }
}
