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
  /// below this triggers Play's blocking *immediate* update flow. `null` (key
  /// missing server-side or never fetched) means nothing is forced.
  String? androidMinVersion;

  /// Latest published Android version, e.g. `"1.0.9"`. Informational — the
  /// soft (flexible) update prompt trusts Play's own availability signal, so
  /// a stale value here can't suppress updates. Reserved for the future iOS
  /// dialog, where no in-app update API exists.
  String? androidLatestVersion;

  static const _tariffHiveKey = 'remote_config.tariff_enabled';
  static const _minVersionHiveKey = 'remote_config.android_min_version';
  static const _latestVersionHiveKey = 'remote_config.android_latest_version';

  /// Seeds the flags from the last cached values. Synchronous, so it can run
  /// at boot before the first frame.
  void hydrateFromCache(Box box) {
    final cached = box.get(_tariffHiveKey);
    if (cached is bool) tariffEnabled = cached;
    final min = box.get(_minVersionHiveKey);
    if (min is String && min.isNotEmpty) androidMinVersion = min;
    final latest = box.get(_latestVersionHiveKey);
    if (latest is String && latest.isNotEmpty) androidLatestVersion = latest;
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
      final (:min, :latest) = parseAndroidVersions(body['value']);
      androidMinVersion = min;
      androidLatestVersion = latest;
      await box.put(_minVersionHiveKey, min ?? '');
      await box.put(_latestVersionHiveKey, latest ?? '');
      appLog.info('[remote-config] android min=$min latest=$latest');
    } on ApiError catch (e, st) {
      if (e.isNotFound) {
        androidMinVersion = null;
        androidLatestVersion = null;
        await box.put(_minVersionHiveKey, '');
        await box.put(_latestVersionHiveKey, '');
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

  /// Extracts `(min, latest)` from the `app_versions` jsonb value:
  /// `{"android": {"min_version": "1.0.0", "latest_version": "1.0.9"}}`.
  /// Defensive against partial / malformed payloads — anything unexpected
  /// reads as `null` rather than throwing during boot.
  static ({String? min, String? latest}) parseAndroidVersions(dynamic value) {
    if (value is! Map) return (min: null, latest: null);
    final android = value['android'];
    if (android is! Map) return (min: null, latest: null);
    String? str(dynamic v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    return (
      min: str(android['min_version']),
      latest: str(android['latest_version']),
    );
  }
}
