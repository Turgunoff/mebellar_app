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
///
/// ## Tree-shaking the mocks (ROADMAP B.7)
///
/// [resolve] takes `mock` as a *nullable* builder. Call sites pass it as
/// `AppConfig.useMocks ? MockX.new : null` — and because `AppConfig.useMocks`
/// is a compile-time `const bool.fromEnvironment`, a production build
/// (`USE_MOCKS=false`) const-folds that ternary to `null`. The `MockX.new`
/// tear-off then sits in statically-dead code, so the AOT compiler drops the
/// mock class — and its canned data — from the release binary entirely.
/// Passing the tear-off directly (the old `mock: MockX.new`) kept every mock
/// permanently reachable as an argument expression.
class RepositoryResolver {
  const RepositoryResolver({
    required this.hasSupabase,
    required this.fulfillmentEnabled,
  });

  /// Reads the build flags from [AppConfig]. [hasSupabase] is passed in by the
  /// caller because it depends on whether `initSupabase()` returned a client
  /// at boot — a runtime fact, not a compile-time flag.
  factory RepositoryResolver.fromEnvironment({required bool hasSupabase}) {
    return RepositoryResolver(
      hasSupabase: hasSupabase,
      fulfillmentEnabled: AppConfig.sellerFulfillmentEnabled,
    );
  }

  /// `true` when `initSupabase()` produced a live client at boot.
  final bool hasSupabase;

  /// ROADMAP A.2 gate — seller fulfillment repositories stay unregistered
  /// until this is flipped on in `env/<env>.json`.
  final bool fulfillmentEnabled;

  /// Supabase-preferred 3-way pick. When a live client exists the Supabase
  /// implementation always wins; otherwise the pick falls to [mock] when one
  /// was supplied and to [remote] when it was not.
  ///
  /// [mock] is nullable *by design*: pass it as `AppConfig.useMocks ? X.new :
  /// null` so a non-mock build const-folds it away and tree-shakes the mock
  /// class (see the class doc). A `null` [mock] therefore means "this build
  /// excludes mocks" — exactly equivalent to the old `useMocks` axis.
  ///
  /// Pass [supabase] as `null` for repositories with no Supabase
  /// implementation — the pick then degrades to the mock/remote axis.
  T resolve<T>({
    T Function()? supabase,
    T Function()? mock,
    required T Function() remote,
  }) {
    if (hasSupabase && supabase != null) return supabase();
    return mock != null ? mock() : remote();
  }

  /// Two-way pick for data sources that have a Supabase implementation and an
  /// offline fallback only — no Dio/REST variant (e.g. `CategoryDataSource`).
  ///
  /// The [fallback] is a genuine offline-resilience path (it is the *only*
  /// option when no Supabase client exists), not dev-only mock data, so it is
  /// intentionally NOT gated behind `AppConfig.useMocks`.
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
