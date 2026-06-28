import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/remote_config.dart';
import '../logging/app_logger.dart';

/// Compares two dotted version strings (`"1.0.9"` vs `"1.0.10"`), ignoring a
/// `+buildNumber` suffix. Missing segments read as 0, non-numeric segments
/// also as 0 — a malformed server value must never crash the gate.
/// Returns <0 / 0 / >0 like [Comparable.compareTo].
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? 0)
      .toList();
  final pa = parse(a);
  final pb = parse(b);
  final length = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < length; i++) {
    final ai = i < pa.length ? pa[i] : 0;
    final bi = i < pb.length ? pb[i] : 0;
    if (ai != bi) return ai - bi;
  }
  return 0;
}

/// `true` when the installed [currentVersion] is below [minRequiredVersion] and
/// the app must force an update. Splits both semantic versions by `.` and
/// compares numerically (see [compareVersions]) — `"1.2.0"` < `"1.10.0"`.
bool isUpdateRequired(String currentVersion, String minRequiredVersion) =>
    compareVersions(currentVersion, minRequiredVersion) < 0;

/// Decides whether the app must force a native update and drives the
/// [AppUpdateGate] overlay.
///
/// This is fully backend-driven and platform-universal: it reads the installed
/// version, compares it against the per-platform `min_version` published in the
/// `app_versions` remote config, and — if below — flips [forceUpdateRequired]
/// so the gate paints a blocking glassmorphism overlay. The overlay's button
/// opens the platform store. There is **no** Google Play `in_app_update` flow
/// anymore; minor updates ride Shorebird OTA, and this gate is strictly for
/// major native releases the operator pins via the admin panel.
///
/// A process singleton — mirrors [RemoteConfig.instance] — so the launch check
/// survives the Phoenix rebirth on customer↔seller mode flips instead of
/// re-evaluating after every switch.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  /// Exact store URLs supplied by the client — the buttons must land on these.
  static const String androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.mebellar.app';
  static const String iosStoreUrl =
      'https://apps.apple.com/us/app/woody-mebellar-olami/id6781271095';

  /// `true` once the installed build is below the platform `min_version`. The
  /// gate listens to this and, once set, the overlay can never be dismissed.
  final ValueNotifier<bool> forceUpdateRequired = ValueNotifier(false);

  bool _checkedThisSession = false;

  // Short-circuits on web before touching `Platform`, which throws there.
  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// One-shot launch check. Awaits the in-flight [RemoteConfig.refresh] (with a
  /// timeout so an offline boot proceeds on the cached value) and then compares
  /// the installed version against the platform threshold.
  Future<void> checkOnLaunch() async {
    if (_checkedThisSession || !_supported) return;
    _checkedThisSession = true;

    await RemoteConfig.instance.whenRefreshed.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );

    final minVersion = Platform.isIOS
        ? RemoteConfig.instance.iosMinVersion
        : RemoteConfig.instance.androidMinVersion;
    if (minVersion == null) return; // nothing pinned server-side

    final installed = (await PackageInfo.fromPlatform()).version;
    final forced = isUpdateRequired(installed, minVersion);
    appLog.info(
      '[app-update] installed=$installed min=$minVersion → '
      '${forced ? 'FORCED' : 'ok'}',
    );
    if (forced) forceUpdateRequired.value = true;
  }

  /// Force-overlay button: open the platform store listing in the native store
  /// app so the user leaves Woody to update.
  Future<void> openStore() async {
    final url = Uri.parse(Platform.isIOS ? iosStoreUrl : androidStoreUrl);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      appLog.handle(e, st, '[app-update] could not open store listing');
    }
  }
}
