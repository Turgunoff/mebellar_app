/// Centralises the "which implementation backs this repository" decision that
/// is currently smeared across ~30 inline ternaries inside
/// `service_locator.dart`.
///
/// The app runs against a 2-way backend matrix:
///   * **Supabase** — live Postgres + realtime; preferred whenever a client
///     was produced at boot.
///   * **Remote** — the legacy Dio/REST implementation, used only when boot
///     ran without a Supabase client (integration tests). Production must
///     always have Supabase — `AppConfig.assertConfigured` enforces that.
///
/// Construct one per DI scope with [RepositoryResolver.fromEnvironment] and
/// let each DI module ask it to [resolve] a registration.
class RepositoryResolver {
  const RepositoryResolver({required this.hasSupabase});

  /// [hasSupabase] is passed in by the caller because it depends on whether
  /// `initSupabase()` returned a client at boot — a runtime fact, not a
  /// compile-time flag.
  factory RepositoryResolver.fromEnvironment({required bool hasSupabase}) {
    return RepositoryResolver(hasSupabase: hasSupabase);
  }

  /// `true` when `initSupabase()` produced a live client at boot.
  final bool hasSupabase;

  /// Supabase-preferred 2-way pick. When a live client exists the Supabase
  /// implementation always wins; otherwise the pick falls back to [remote].
  ///
  /// Pass [supabase] as `null` for repositories with no Supabase
  /// implementation — the pick then degrades to [remote] unconditionally.
  T resolve<T>({
    T Function()? supabase,
    required T Function() remote,
  }) {
    if (hasSupabase && supabase != null) return supabase();
    return remote();
  }
}
