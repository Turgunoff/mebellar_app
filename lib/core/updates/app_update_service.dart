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

/// Which blocking overlay the [AppUpdateGate] should paint, if any.
enum AppGateState {
  none,

  /// The marketplace is frozen server-side — show the maintenance overlay.
  /// Takes priority over [forceUpdate].
  maintenance,

  /// The installed build is below the platform `min_version` — show the
  /// force-update overlay.
  forceUpdate,
}

/// Decides whether the app must be blocked at launch — by a server-side
/// maintenance freeze or a mandatory native update — and drives the
/// [AppUpdateGate] overlay.
///
/// Fully backend-driven and platform-universal. At launch it reads the
/// `maintenance` and `app_versions` remote config and sets [gateState]:
/// maintenance is checked FIRST (it wins over a pending update), then the
/// installed version is compared against the per-platform `min_version`. The
/// force-update overlay's button opens the platform store. There is **no**
/// Google Play `in_app_update` flow — minor updates ride Shorebird OTA, and
/// this gate is strictly for the major native releases / freezes the operator
/// pins via the admin panel.
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

  /// Which overlay (if any) the gate must paint. Once set to a blocking state
  /// the overlay can never be dismissed.
  final ValueNotifier<AppGateState> gateState = ValueNotifier(
    AppGateState.none,
  );

  bool _checkedThisSession = false;

  // Short-circuits on web before touching `Platform`, which throws there.
  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// One-shot launch check. Awaits the in-flight [RemoteConfig.refresh] (with a
  /// timeout so an offline boot proceeds on cached values), then resolves the
  /// gate: maintenance freeze first, then the force-update version compare.
  Future<void> checkOnLaunch() async {
    if (_checkedThisSession || !_supported) return;
    _checkedThisSession = true;

    await RemoteConfig.instance.whenRefreshed.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );

    // 1. Maintenance freeze takes priority over a pending update.
    if (RemoteConfig.instance.maintenanceEnabled) {
      appLog.info('[app-gate] maintenance mode active');
      gateState.value = AppGateState.maintenance;
      return;
    }

    // 2. Force update — installed build below the platform threshold.
    final minVersion = Platform.isIOS
        ? RemoteConfig.instance.iosMinVersion
        : RemoteConfig.instance.androidMinVersion;
    if (minVersion == null) return; // nothing pinned server-side

    final installed = (await PackageInfo.fromPlatform()).version;
    final forced = isUpdateRequired(installed, minVersion);
    appLog.info(
      '[app-gate] installed=$installed min=$minVersion → '
      '${forced ? 'FORCE UPDATE' : 'ok'}',
    );
    if (forced) gateState.value = AppGateState.forceUpdate;
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
