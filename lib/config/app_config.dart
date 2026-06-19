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

  /// Payme (Paycom) Subscribe API base for DIRECT card tokenisation from the
  /// app (X-Auth: merchant_id only — no key in the app). Test:
  /// `https://checkout.test.paycom.uz/api`, prod: `https://checkout.paycom.uz/api`.
  /// Optional: when unset, card payments are hidden and the app stays COD-only,
  /// so a build with no Payme config still boots (unlike the required keys).
  static const String paymeApiUrl = String.fromEnvironment('PAYME_API_URL');

  /// Payme merchant id (public-side identifier sent as the `X-Auth` header for
  /// card tokenisation). The merchant KEY is NEVER in the app — only the
  /// backend holds it.
  static const String paymeMerchantId = String.fromEnvironment(
    'PAYME_MERCHANT_ID',
  );

  /// Routes card payments through an in-app MOCK of Payme — the full add-card +
  /// pay flow runs end-to-end with NO real Payme credentials (demos / QA).
  /// When true, [hasPayme] lights up the card UI and `core_module.dart` swaps
  /// `MockPaymeClient` in for the real client (and the backend must run with its
  /// own `PAYME_MOCK=true`). Defaults OFF so production is never silently
  /// mocked.
  static const bool paymeMock = bool.fromEnvironment(
    'PAYME_MOCK',
    defaultValue: false,
  );

  static bool get isProd => environment == 'prod';

  static bool get hasWoodyApi => woodyApiUrl.isNotEmpty;

  /// Whether card payments are available. True when either the mock is on
  /// ([paymeMock]) or real Payme tokenisation is configured. False → the app
  /// shows only Cash on Delivery.
  static bool get hasPayme =>
      paymeMock || (paymeApiUrl.isNotEmpty && paymeMerchantId.isNotEmpty);

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
