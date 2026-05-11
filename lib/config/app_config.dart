/// App-wide configuration loaded via `--dart-define-from-file=env/<env>.json`.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oifdvxsfrciatzgivtgs.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9pZmR2eHNmcmNpYXR6Z2l2dGdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2MzIyOTQsImV4cCI6MjA5MzIwODI5NH0.3ptpS4WFsLW-EHt6EVr-gSLOjGRAew405HTZ2CwWj98',
  );

  static const String yandexGeocoderApiKey = String.fromEnvironment(
    'YANDEX_GEOCODER_API_KEY',
    defaultValue: '',
  );

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// When true, content repositories (products, shops, categories, banners)
  /// return canned data instead of hitting the API. Useful while the backend
  /// catalog endpoints are still in development.
  static const bool useMocks = bool.fromEnvironment(
    'USE_MOCKS',
    defaultValue: true,
  );

  static bool get isProd => environment == 'prod';

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
