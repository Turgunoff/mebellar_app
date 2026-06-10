import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/remote_config.dart';
import '../logging/talker.dart';

/// What the update gate should do after a Play check.
enum AppUpdateAction { none, flexible, immediate }

/// UI surface the [AppUpdateGate] renders. Driven by [AppUpdateService].
enum AppUpdateUiState {
  idle,

  /// The installed build is below the backend `min_version` and the Play
  /// immediate flow was denied/unavailable — show the blocking overlay.
  forceBlocked,

  /// A flexible update finished downloading — offer a restart.
  flexibleReady,
}

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

/// Decides between Play's blocking *immediate* flow and the quiet *flexible*
/// flow. The backend `min_version` is the only force trigger; the soft prompt
/// trusts Play's own availability signal, so users see new builds without the
/// backend row needing a bump every release.
AppUpdateAction resolveUpdateAction({
  required bool playUpdateAvailable,
  required bool immediateAllowed,
  required bool flexibleAllowed,
  required String installedVersion,
  String? minVersion,
}) {
  if (!playUpdateAvailable) return AppUpdateAction.none;
  final forced =
      minVersion != null && compareVersions(installedVersion, minVersion) < 0;
  if (forced) {
    if (immediateAllowed) return AppUpdateAction.immediate;
    if (flexibleAllowed) return AppUpdateAction.flexible;
    return AppUpdateAction.none;
  }
  return flexibleAllowed ? AppUpdateAction.flexible : AppUpdateAction.none;
}

/// Orchestrates Google Play in-app updates (Android only).
///
/// A process singleton — mirrors [RemoteConfig.instance] — so the launch
/// check survives the Phoenix rebirth on customer↔seller mode flips instead
/// of re-prompting after every switch. [AppUpdateGate] (mounted in both
/// MaterialApp builders) renders whatever [uiState] says and forwards
/// lifecycle resumes here.
///
/// Debug builds skip everything: in-app updates only work for Play-installed
/// builds, so a dev run would just throw `PlatformException` noise.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  final ValueNotifier<AppUpdateUiState> uiState = ValueNotifier(
    AppUpdateUiState.idle,
  );

  bool _checkedThisSession = false;
  bool _immediateInProgress = false;
  String _packageName = 'com.mebellar.app';

  bool get _supported => !kIsWeb && !kDebugMode && Platform.isAndroid;

  /// One-shot launch check. Awaits the in-flight [RemoteConfig.refresh] (with
  /// a timeout so an offline boot proceeds on cached values) and then asks
  /// Play whether an update exists.
  Future<void> checkOnLaunch() async {
    if (!_supported || _checkedThisSession) return;
    _checkedThisSession = true;

    await RemoteConfig.instance.whenRefreshed.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );

    final packageInfo = await PackageInfo.fromPlatform();
    _packageName = packageInfo.packageName;
    final installed = packageInfo.version;
    final minVersion = RemoteConfig.instance.androidMinVersion;

    AppUpdateInfo info;
    try {
      info = await InAppUpdate.checkForUpdate();
    } catch (e, st) {
      // Not a Play-installed build (sideloaded APK) or Play is unreachable.
      // A backend-forced version still blocks — the overlay's button routes
      // to the Play listing instead of the in-app flow.
      talker.handle(e, st, '[app-update] Play check failed');
      final forced =
          minVersion != null && compareVersions(installed, minVersion) < 0;
      if (forced) uiState.value = AppUpdateUiState.forceBlocked;
      return;
    }

    final action = resolveUpdateAction(
      playUpdateAvailable:
          info.updateAvailability == UpdateAvailability.updateAvailable,
      immediateAllowed: info.immediateUpdateAllowed,
      flexibleAllowed: info.flexibleUpdateAllowed,
      installedVersion: installed,
      minVersion: minVersion,
    );
    talker.info(
      '[app-update] installed=$installed min=$minVersion '
      'play=${info.updateAvailability.name} → ${action.name}',
    );

    switch (action) {
      case AppUpdateAction.none:
        return;
      case AppUpdateAction.immediate:
        await _runImmediate();
      case AppUpdateAction.flexible:
        await _runFlexible();
    }
  }

  /// Re-entry point for app resumes: Play's immediate flow can be interrupted
  /// (user backgrounds mid-download) and must be resumed manually, and a
  /// flexible download finished in the background becomes installable.
  Future<void> onResumed() async {
    if (!_supported || !_checkedThisSession) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        if (_immediateInProgress) await _runImmediate();
        return;
      }
      if (info.installStatus == InstallStatus.downloaded &&
          uiState.value == AppUpdateUiState.idle) {
        uiState.value = AppUpdateUiState.flexibleReady;
      }
    } catch (_) {
      // Resume checks are opportunistic — stay quiet off Play installs.
    }
  }

  Future<void> _runImmediate() async {
    _immediateInProgress = true;
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      if (result == AppUpdateResult.success) {
        // Play restarts the app into the new build; nothing left to do.
        _immediateInProgress = false;
        uiState.value = AppUpdateUiState.idle;
        return;
      }
      // Denied or failed: the update is mandatory, so block the app with our
      // own overlay — its button re-launches the flow.
      uiState.value = AppUpdateUiState.forceBlocked;
    } catch (e, st) {
      talker.handle(e, st, '[app-update] immediate flow crashed');
      uiState.value = AppUpdateUiState.forceBlocked;
    }
  }

  Future<void> _runFlexible() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      // The future completes when the background download finishes.
      if (result == AppUpdateResult.success) {
        uiState.value = AppUpdateUiState.flexibleReady;
      }
    } catch (e, st) {
      talker.handle(e, st, '[app-update] flexible flow failed');
    }
  }

  /// Force-overlay button: retry the Play immediate flow; if that can't even
  /// start (sideloaded build), open the Play listing.
  Future<void> retryForcedUpdate() async {
    try {
      await InAppUpdate.checkForUpdate();
      await _runImmediate();
      if (uiState.value == AppUpdateUiState.idle) return;
    } catch (_) {
      // Fall through to the store listing.
    }
    await openStoreListing();
  }

  /// Restart-banner button: applies the downloaded flexible update (Play
  /// restarts the app).
  Future<void> completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e, st) {
      talker.handle(e, st, '[app-update] completeFlexibleUpdate failed');
      uiState.value = AppUpdateUiState.idle;
    }
  }

  void dismissFlexibleBanner() {
    if (uiState.value == AppUpdateUiState.flexibleReady) {
      uiState.value = AppUpdateUiState.idle;
    }
  }

  Future<void> openStoreListing() async {
    final market = Uri.parse('market://details?id=$_packageName');
    final web = Uri.parse(
      'https://play.google.com/store/apps/details?id=$_packageName',
    );
    try {
      final opened = await launchUrl(
        market,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        await launchUrl(web, mode: LaunchMode.externalApplication);
      }
    } catch (e, st) {
      talker.handle(e, st, '[app-update] could not open Play listing');
    }
  }
}
