import '../../config/app_config.dart';

/// Centralises the "which implementation backs this repository" decision that
/// is currently smeared across ~30 inline ternaries inside
/// `service_locator.dart`.
///
/// The app runs against a 3-way backend matrix:
///   * **Supabase** — live Postgres + realtime; preferred whenever a client
///     was produced at boot, so even mock-flagged dev builds exercise the
///     real schema.
///   * **Mock** — in-memory canned data for `AppConfig.useMocks` builds with
///     no Supabase implementation available.
///   * **Remote** — the legacy Dio/REST implementation.
///
/// Construct one per DI scope with [RepositoryResolver.fromEnvironment] and
/// let each DI module ask it to [resolve] a registration.
class RepositoryResolver {
  const RepositoryResolver({
    required this.useMocks,
    required this.hasSupabase,
    required this.fulfillmentEnabled,
  });

  /// Reads the build flags from [AppConfig]. [hasSupabase] is passed in by the
  /// caller because it depends on whether `initSupabase()` returned a client
  /// at boot — a runtime fact, not a compile-time flag.
  factory RepositoryResolver.fromEnvironment({required bool hasSupabase}) {
    return RepositoryResolver(
      useMocks: AppConfig.useMocks,
      hasSupabase: hasSupabase,
      fulfillmentEnabled: AppConfig.sellerFulfillmentEnabled,
    );
  }

  /// `true` on dev builds that should fall back to canned in-memory data.
  final bool useMocks;

  /// `true` when `initSupabase()` produced a live client at boot.
  final bool hasSupabase;

  /// ROADMAP A.2 gate — seller fulfillment repositories stay unregistered
  /// until this is flipped on in `env/<env>.json`.
  final bool fulfillmentEnabled;

  /// Supabase-preferred 3-way pick. When a live client exists the Supabase
  /// implementation always wins; otherwise mock vs remote depends on
  /// [useMocks].
  ///
  /// Pass [supabase] as `null` for repositories with no Supabase
  /// implementation — the pick then degrades to the mock/remote axis.
  T resolve<T>({
    T Function()? supabase,
    required T Function() mock,
    required T Function() remote,
  }) {
    if (hasSupabase && supabase != null) return supabase();
    return useMocks ? mock() : remote();
  }

  /// Two-way pick for data sources that have a Supabase implementation and an
  /// offline fallback only — no Dio/REST variant (e.g. `CategoryDataSource`).
  T resolveOrFallback<T>({
    required T Function() supabase,
    required T Function() fallback,
  }) {
    return hasSupabase ? supabase() : fallback();
  }

  /// Runs [register] only when [fulfillmentEnabled] is on. Keeps the A.2
  /// feature-flag gate out of the call sites.
  void whenFulfillmentEnabled(void Function() register) {
    if (fulfillmentEnabled) register();
  }
}
