/// App-wide configuration loaded via `--dart-define-from-file=env/<env>.json`.
///
/// Secrets — the Woody API URL, the Yandex Geocoder key — have **no
/// compiled-in defaults**. A build with no env file leaves them empty and
/// [assertConfigured] aborts boot. This is what keeps real credentials out of
/// the source tree and the decompiled APK (ROADMAP A.1/A.4).
class AppConfig {
  const AppConfig._();

  /// Base URL for the woody_backend FastAPI service at `api.woody.uz`.
  /// Routes mount under `/api/v1` — `WoodyApiClient` adds the prefix.
  static const String woodyApiUrl = String.fromEnvironment('WOODY_API_URL');

  static const String yandexGeocoderApiKey = String.fromEnvironment(
    'YANDEX_GEOCODER_API_KEY',
  );

  /// Deployment environment tag. Non-secret: a missing value safely resolves
  /// to the non-production `dev` profile, so `isProd` can never be true by
  /// accident.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// Routes seller mode through `go_router` (a `StatefulShellRoute`) instead
  /// of the legacy imperative `MaterialApp` + `sellerNavigatorKey` shell.
  /// The extracted seller screen structure (ROADMAP B.4) is in place, so this
  /// defaults ON; flip OFF in an env file to fall back to the legacy
  /// navigation while debugging (ROADMAP B.3).
  static const bool sellerUsesGoRouter = bool.fromEnvironment(
    'SELLER_USES_GO_ROUTER',
    defaultValue: true,
  );

  /// Sends normalised profile fields (phone, name, email) to Meta for
  /// Advanced Matching — it raises the rate at which Meta can match an app
  /// event to a real account, which is what makes App Promotion campaigns
  /// optimise well.
  ///
  /// **Default OFF, and it must stay OFF until three things ship together:**
  /// the privacy policy names the fields being shared, `PrivacyInfo.xcprivacy`
  /// declares PhoneNumber / Name / EmailAddress, and the App Store Connect
  /// questionnaire matches. Sharing a phone number with an ad network without
  /// that paperwork is a legal problem, not a tuning knob — see
  /// `doc/release_checklist.md`.
  ///
  /// Runtime consent (ATT + the in-app analytics toggle) still gates this on
  /// top: the flag can only ever narrow what is sent, never widen it.
  static const bool metaAdvancedMatchingEnabled = bool.fromEnvironment(
    'META_ADVANCED_MATCHING_ENABLED',
  );

  static bool get isProd => environment == 'prod';

  static bool get hasWoodyApi => woodyApiUrl.isNotEmpty;

  /// Required keys that have no safe fallback. Missing any of these is a build
  /// misconfiguration, not a recoverable runtime state.
  static List<String> get missingRequiredKeys => [
    if (woodyApiUrl.isEmpty) 'WOODY_API_URL',
    if (yandexGeocoderApiKey.isEmpty) 'YANDEX_GEOCODER_API_KEY',
  ];

  /// Fail-fast guard. Call once at the very top of `main()`: a build launched
  /// without an env file aborts here — loudly — instead of silently running
  /// against empty credentials.
  static void assertConfigured() {
    final missing = missingRequiredKeys;
    if (missing.isEmpty) return;
    throw StateError(
      'AppConfig: missing required env keys: ${missing.join(', ')}. '
      'Launch with --dart-define-from-file=env/prod.json '
      '(see env/example.json for the expected shape).',
    );
  }
}
