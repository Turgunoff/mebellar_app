/// App-wide configuration loaded via `--dart-define-from-file=env/<env>.json`.
///
/// Secrets — the Supabase URL/anon key, the Yandex Geocoder key — have
/// **no compiled-in defaults**. A build with no env file leaves them empty
/// and [assertConfigured] aborts boot. This is what keeps real credentials
/// out of the source tree and the decompiled APK (ROADMAP A.1/A.4).
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Base URL for the woody_backend FastAPI service at `api.woody.uz`.
  /// Routes mount under `/api/v1` — `WoodyApiClient` adds the prefix.
  static const String woodyApiUrl = String.fromEnvironment('WOODY_API_URL');

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String yandexGeocoderApiKey =
      String.fromEnvironment('YANDEX_GEOCODER_API_KEY');

  /// Deployment environment tag. Non-secret: a missing value safely resolves
  /// to the non-production `dev` profile, so `isProd` can never be true by
  /// accident.
  static const String environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

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

  static bool get hasWoodyApi => woodyApiUrl.isNotEmpty;

  /// Required keys that have no safe fallback. Missing any of these is a build
  /// misconfiguration, not a recoverable runtime state. Supabase keys are now
  /// optional — they're only used by feature surfaces that haven't completed
  /// the Phase 8 cleanup yet (seller products CRUD, analytics, reviews,
  /// services, shop settings, tariff). Builds without Supabase keys boot
  /// successfully; those specific surfaces fall back to read-only / disabled.
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
