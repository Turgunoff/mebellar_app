import 'dart:async';
import 'dart:convert';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';
import 'meta_consent_gate.dart';

/// Wrapper over the Facebook App Events SDK (`facebook_app_events`), kept
/// SEPARATE from [AnalyticsService] (which fans into Firebase): Meta is its own
/// conversion sink, used for ad-campaign attribution (installs, the e-commerce
/// funnel, and a few custom high-value signals).
///
/// Consent-first
///
/// The SDK is wired to NOT auto-initialise: `FacebookAutoLogAppEventsEnabled`
/// / `FacebookAdvertiserIDCollectionEnabled` (iOS) and the matching
/// `com.facebook.sdk.*` flags (Android) are set to `false` in the native
/// config. Nothing is tracked until [initialize] runs and resolves consent
/// through [MetaConsentGate]:
///
/// - **iOS** gates everything on App Tracking Transparency. If the user
///   declines the ATT prompt, [initialize] leaves the SDK disabled and every
///   event method becomes a no-op — we respect the choice.
/// - **Android** has no ATT; [initialize] turns the SDK on immediately
///   *unless* the in-app "Foydalanish statistikasi" privacy toggle has opted
///   out (see [setPrivacyCollectionAllowed]).
///
/// Both gates must pass — ATT (iOS) AND the Hive analytics preference —
/// before any Meta event is sent.
///
/// ## Non-throwing
///
/// Every method is side-effecting and swallows its own errors (analytics must
/// never break a user flow). The instance is a lazy GetIt singleton (root
/// scope — see `catalog_module`), shared by customer + seller call sites, so
/// they never need to null-check.
///
/// ## Debug console
///
/// In `kDebugMode` every event prints a formatted line — e.g.
/// `[META ANALYTICS] 🚀 Event: Purchase | Value: 4,500,000 UZS | Params: …` —
/// and is flushed to Meta immediately so it shows up in
/// Events Manager → Test Events in real time. All of this is compiled out of
/// release builds by the `kDebugMode` guard.
class FacebookAnalyticsService {
  FacebookAnalyticsService({
    FacebookAppEvents? events,
    MetaConsentGate? consent,
  }) : _fb = events ?? FacebookAppEvents(),
       _consent = consent ?? const MetaConsentGate();

  final FacebookAppEvents _fb;
  final MetaConsentGate _consent;

  /// Currency for the marketplace — every monetary event rides UZS.
  static const _currency = 'UZS';

  bool _initialized = false;
  bool _enabled = false;

  /// ATT / platform consent from the last [initialize] call. Kept separate
  /// from [_privacyAllowed] so flipping the Settings toggle doesn't need to
  /// re-prompt ATT — it just re-ANDs the two gates.
  bool _attAllowed = false;

  /// In-app privacy preference (Hive `analytics_collection_enabled`). Defaults
  /// to true until boot / Settings applies the stored value.
  bool _privacyAllowed = true;

  /// Whether Meta tracking is live (consent granted + privacy allowed + SDK on).
  bool get isEnabled => _enabled;

  /// Applies the Settings "Foydalanish statistikasi" preference. Safe to call
  /// before or after [initialize] — before, it just stashes the value for
  /// initialize to honour; after, it immediately turns Meta collection on/off
  /// without re-prompting ATT.
  Future<void> setPrivacyCollectionAllowed(bool allowed) async {
    _privacyAllowed = allowed;
    if (!_initialized) return;
    await _applyEnabledState(activateIfNewlyEnabled: false);
  }

  /// Resolves consent and brings the SDK online (or leaves it off). Idempotent
  /// — safe to call from multiple entry points / across mode switches; the ATT
  /// prompt only ever shows once (iOS shows its dialog once per install).
  /// Must be invoked once the app is foregrounded past the splash so the iOS
  /// system dialog doesn't paint over the brand splash.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _attAllowed = await _consent.requestTrackingAuthorization();
    } catch (e, st) {
      // A failed ATT round-trip must never crash boot — fail closed (no
      // tracking) and move on.
      appLog.handle(e, st, 'FacebookAnalyticsService: consent resolution');
      _attAllowed = false;
    }

    await _applyEnabledState(activateIfNewlyEnabled: true);
  }

  /// Recomputes `_enabled = ATT ∧ privacy` and mirrors it onto the SDK
  /// switches. [activateIfNewlyEnabled] records the activation event only on
  /// the first successful enable (initialize path) — toggling privacy back
  /// on mid-session shouldn't re-fire activateApp.
  Future<void> _applyEnabledState({
    required bool activateIfNewlyEnabled,
  }) async {
    final allowed = _attAllowed && _privacyAllowed;
    final wasEnabled = _enabled;
    _enabled = allowed;

    await _safe(() async {
      await _fb.setAutoLogAppEventsEnabled(allowed);
      await _fb.setAdvertiserIdCollectionEnabled(allowed);
      if (allowed && activateIfNewlyEnabled && !wasEnabled) {
        if (kDebugMode) await _fb.setDebugLoggingEnabled(true);
        await _fb.activateApp();
      }
    });

    _console(
      allowed
          ? '✅ SDK initialised — tracking authorised'
          : _attAllowed && !_privacyAllowed
          ? '🔒 SDK suppressed — in-app analytics privacy opt-out'
          : '🔒 SDK initialised — tracking declined (events suppressed)',
    );
  }

  // ── standard e-commerce events ──────────────────────────────────────────

  /// Standard event `ViewContent` — the buyer opened a product detail.
  Future<void> logViewContent({
    required String contentId,
    required String contentName,
    required double value,
    String currency = _currency,
  }) => _track(
    event: 'ViewContent',
    value: value,
    params: {
      'content_id': contentId,
      'content_type': 'product',
      'content_name': contentName,
    },
    op: () => _fb.logViewContent(
      id: contentId,
      type: 'product',
      price: value,
      currency: currency,
      parameters: {'content_name': contentName},
    ),
  );

  /// Standard event `AddToCart`. [value] rides as the summed amount so Meta can
  /// attribute cart value to a campaign.
  Future<void> logAddToCart(
    String contentId,
    double value, {
    String? contentName,
  }) => _track(
    event: 'AddToCart',
    value: value,
    params: {
      'content_id': contentId,
      'content_type': 'product',
      'content_name': ?contentName,
    },
    op: () => _fb.logAddToCart(
      id: contentId,
      type: 'product',
      currency: _currency,
      price: value,
      parameters: {'content_name': ?contentName},
    ),
  );

  /// Standard event `InitiateCheckout` — the buyer reached the checkout screen.
  Future<void> logInitiateCheckout({
    required int numItems,
    required double value,
    String currency = _currency,
  }) => _track(
    event: 'InitiateCheckout',
    value: value,
    params: {'num_items': numItems},
    op: () => _fb.logInitiatedCheckout(
      totalPrice: value,
      currency: currency,
      numItems: numItems,
    ),
  );

  /// Standard event `Purchase` — the top conversion signal in the funnel.
  /// [contentIds] are the purchased product ids; [numItems] the line count;
  /// [orderId] dedups the transaction on Meta's side (mirrors the Firebase
  /// `transactionId`) so a retry / multi-shop fan-out is never double-counted.
  Future<void> logPurchase(
    double amount,
    String currency, {
    List<String>? contentIds,
    int? numItems,
    String? orderId,
  }) => _track(
    event: 'Purchase',
    value: amount,
    params: {
      'content_ids': ?contentIds,
      'num_items': ?numItems,
      'order_id': ?orderId,
    },
    op: () => _fb.logPurchase(
      amount: amount,
      currency: currency,
      parameters: {
        if (contentIds != null) 'fb_content_id': json.encode(contentIds),
        'fb_num_items': ?numItems,
        'fb_order_id': ?orderId,
      },
    ),
  );

  // ── lifecycle / custom ──────────────────────────────────────────────────

  /// Standard event `CompleteRegistration` — the user finished sign-up.
  Future<void> logRegistration() => _track(
    event: 'CompleteRegistration',
    params: {'method': 'phone_otp'},
    op: () => _fb.logCompletedRegistration(registrationMethod: 'phone_otp'),
  );

  /// Arbitrary custom event (AR usage, AI designer usage, seller 3D generation).
  Future<void> logCustomEvent(
    String eventName,
    Map<String, dynamic> parameters,
  ) => _track(
    event: eventName,
    params: parameters,
    op: () => _fb.logEvent(
      name: eventName,
      parameters: parameters.isEmpty ? null : parameters,
    ),
  );

  /// Tag subsequent events with the signed-in user; pass `null` on sign-out.
  /// No-op while tracking is suppressed.
  Future<void> setUserId(String? userId) async {
    if (!_enabled) return;
    await _safe(
      () => userId == null ? _fb.clearUserID() : _fb.setUserID(userId),
    );
  }

  // ── internals ───────────────────────────────────────────────────────────

  /// Logs the event to the debug console (always, so a suppressed event is
  /// still visible while testing) and, only when tracking is enabled, runs the
  /// SDK call and flushes it for real-time Test Events.
  Future<void> _track({
    required String event,
    required Future<void> Function() op,
    double? value,
    Map<String, Object?> params = const {},
  }) async {
    _console(
      '${_enabled ? '🚀' : '⏸️'} Event: $event'
      '${value == null ? '' : ' | Value: ${_grouped(value)} UZS'}'
      ' | Params: $params'
      '${_enabled ? '' : ' (suppressed — tracking not authorised)'}',
    );
    if (!_enabled) return;
    await _safe(() async {
      await op();
      // Force an immediate flush in debug so the event lands in Meta Events
      // Manager → Test Events in real time instead of waiting for the batch.
      if (kDebugMode) await _fb.flush();
    });
  }

  /// Prints a uniform, easy-to-scan line in debug; compiled out of release.
  void _console(String message) {
    if (kDebugMode) debugPrint('[META ANALYTICS] $message');
  }

  Future<void> _safe(Future<void> Function() op) async {
    try {
      await op();
    } catch (e, st) {
      appLog.handle(e, st, 'FacebookAnalyticsService');
    }
  }

  /// `4500000` → `4,500,000` for the debug console value column.
  static String _grouped(num value) {
    final n = value.round();
    final digits = n.abs().toString();
    final buf = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i != 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}
