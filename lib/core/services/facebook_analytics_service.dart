import 'package:facebook_app_events/facebook_app_events.dart';

import '../logging/talker.dart';

/// Thin wrapper over the Facebook App Events SDK (`facebook_app_events`),
/// kept SEPARATE from [AnalyticsService] (which fans into Firebase): Facebook
/// is its own conversion sink, used for ad-campaign attribution (app installs,
/// standard conversions, and a few custom high-value signals).
///
/// Every method is side-effecting and NON-throwing — analytics must never
/// break a user flow — so each SDK call is wrapped and failures are only
/// logged. The instance is a lazy GetIt singleton (see `catalog_module`),
/// shared by customer + seller call sites.
///
/// **App installs + sessions are tracked automatically** once the native App
/// ID / Client Token are configured (AndroidManifest `<meta-data>` /
/// Info.plist). Those are currently PLACEHOLDERS (`YOUR_FB_APP_ID` /
/// `YOUR_FB_CLIENT_TOKEN`) — replace them with the real Facebook App dashboard
/// values before running a campaign, or the events go nowhere.
class FacebookAnalyticsService {
  FacebookAnalyticsService() {
    // Best-effort init: turn on automatic install/session logging and record
    // this activation. Swallowed — in a test (no native plugin) these throw a
    // MissingPluginException, which must never propagate out of a constructor.
    unawaitedSafe(() => _fb.setAutoLogAppEventsEnabled(true));
    unawaitedSafe(() => _fb.activateApp());
  }

  final FacebookAppEvents _fb = FacebookAppEvents();

  /// Standard event `CompleteRegistration` — the user finished sign-up.
  Future<void> logRegistration() => _safe(
    () => _fb.logCompletedRegistration(registrationMethod: 'phone_otp'),
  );

  /// Standard event `AddToCart`. [price] rides as the summed value so Facebook
  /// can attribute cart value to a campaign.
  Future<void> logAddToCart(String productId, double price) => _safe(
    () => _fb.logEvent(
      name: FacebookAppEvents.eventNameAddedToCart,
      parameters: {'fb_content_id': productId, 'fb_currency': 'UZS'},
      valueToSum: price,
    ),
  );

  /// Standard event `Purchase` — the top conversion signal in the funnel.
  Future<void> logPurchase(double amount, String currency) =>
      _safe(() => _fb.logPurchase(amount: amount, currency: currency));

  /// Arbitrary custom event (AR usage, AI designer usage, seller 3D generation).
  Future<void> logCustomEvent(
    String eventName,
    Map<String, dynamic> parameters,
  ) => _safe(
    () => _fb.logEvent(
      name: eventName,
      parameters: parameters.isEmpty ? null : parameters,
    ),
  );

  /// Tag subsequent events with the signed-in user; pass `null` on sign-out.
  Future<void> setUserId(String? userId) => _safe(
    () => userId == null ? _fb.clearUserID() : _fb.setUserID(userId),
  );

  Future<void> _safe(Future<void> Function() op) async {
    try {
      await op();
    } catch (e, st) {
      talker.handle(e, st, 'FacebookAnalyticsService');
    }
  }

  /// Fire-and-forget variant for constructor-time init calls.
  void unawaitedSafe(Future<void> Function() op) {
    _safe(op);
  }
}
