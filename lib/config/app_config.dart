/// App-wide configuration loaded via `--dart-define-from-file=env/<env>.json`.
///
/// Secrets — the Supabase URL/anon key, the Yandex Geocoder key, the Sentry
/// DSN — have **no compiled-in defaults**. A build with no env file leaves
/// them empty and [assertConfigured] aborts boot. This is what keeps real
/// credentials out of the source tree and the decompiled APK (ROADMAP A.1/A.4).
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String yandexGeocoderApiKey =
      String.fromEnvironment('YANDEX_GEOCODER_API_KEY');

  /// Crash-reporting DSN. Empty ⇒ Sentry initialises in a disabled state and
  /// every `captureException` becomes a no-op (see `main.dart`).
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Deployment environment tag. Non-secret: a missing value safely resolves
  /// to the non-production `dev` profile, so `isProd` can never be true by
  /// accident.
  static const String environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// When true, content repositories (products, shops, categories, banners)
  /// return canned data instead of hitting the API. Useful while the backend
  /// catalog endpoints are still in development.
  static const bool useMocks = bool.fromEnvironment(
    'USE_MOCKS',
    defaultValue: true,
  );

  /// Gates the seller fulfillment surfaces that are still backed only by
  /// in-memory mocks — orders, shop settings, seller services, and KYC
  /// verification. Defaults OFF so a production build can never surface fake
  /// order/settings data to a real seller (ROADMAP A.2). Flip to true in an
  /// env file once the Supabase repositories from ROADMAP B.1 ship.
  static const bool sellerFulfillmentEnabled = bool.fromEnvironment(
    'SELLER_FULFILLMENT_ENABLED',
    defaultValue: false,
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

  static bool get isProd => environment == 'prod';

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Required keys that have no safe fallback. Missing any of these is a build
  /// misconfiguration, not a recoverable runtime state.
  static List<String> get missingRequiredKeys => [
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
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
