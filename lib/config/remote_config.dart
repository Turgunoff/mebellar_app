import 'package:hive_flutter/hive_flutter.dart';

import '../core/logging/talker.dart';
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

  static const _tariffHiveKey = 'remote_config.tariff_enabled';

  /// Seeds [tariffEnabled] from the last cached value. Synchronous, so it can
  /// run at boot before the first frame.
  void hydrateFromCache(Box box) {
    final cached = box.get(_tariffHiveKey);
    if (cached is bool) tariffEnabled = cached;
  }

  /// Re-fetches the flag from `GET /catalog/settings/tariff_enabled`.
  /// Best-effort: on any failure the cached/default value is kept, so boot is
  /// never blocked on the network. A 404 means the flag isn't configured
  /// server-side, which we treat as *disabled* (tariff stays off rather than
  /// gating sellers behind a paywall).
  Future<void> refresh(WoodyApiClient api, Box box) async {
    try {
      final body = await api
          .get<Map<String, dynamic>>('/catalog/settings/tariff_enabled')
          .timeout(const Duration(seconds: 6));
      // `value` is the jsonb column — a boolean, but tolerate 'true' too.
      final value = body['value'];
      tariffEnabled = value == true || value == 'true';
      await box.put(_tariffHiveKey, tariffEnabled);
      talker.info('[remote-config] tariff_enabled=$tariffEnabled');
    } on ApiError catch (e, st) {
      if (e.isNotFound) {
        tariffEnabled = false;
        await box.put(_tariffHiveKey, false);
        return;
      }
      talker.handle(
        e,
        st,
        '[remote-config] refresh failed — kept cached value',
      );
    } catch (e, st) {
      talker.handle(
        e,
        st,
        '[remote-config] refresh failed — kept cached value',
      );
    }
  }
}
