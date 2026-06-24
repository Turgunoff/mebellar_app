import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Privacy gate that decides whether Meta (Facebook) App Events tracking is
/// permitted on this device, and — on iOS — surfaces the App Tracking
/// Transparency (ATT) system prompt to ask.
///
/// Apple requires an explicit ATT grant before an app may read the IDFA or
/// share device-level signals with an ad SDK. Android has no equivalent
/// gate, so tracking is allowed there as soon as the SDK is wired. Every
/// other platform (web/desktop in tests) is treated like Android.
///
/// This is a thin, side-effect-only seam so [FacebookAnalyticsService] can be
/// unit-tested with a fake gate (the real one talks to a platform channel).
class MetaConsentGate {
  const MetaConsentGate();

  /// Resolves the user's tracking choice, prompting once if it has never been
  /// asked. Returns `true` only when tracking is authorised.
  ///
  /// On iOS: reads [TrackingStatus]; if `notDetermined`, shows the ATT dialog
  /// and awaits the user's answer. `authorized` ⇒ allowed; `denied` /
  /// `restricted` ⇒ blocked (we respect the choice and never re-prompt — iOS
  /// only ever shows the dialog once anyway). On all other platforms it
  /// returns `true` without touching the channel.
  Future<bool> requestTrackingAuthorization() async {
    if (!Platform.isIOS) return true;

    var status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      status = await AppTrackingTransparency.requestTrackingAuthorization();
    }
    return status == TrackingStatus.authorized;
  }
}
