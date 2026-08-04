import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/app_mode.dart';
import '../analytics/analytics_service.dart';

/// Reactive holder for the active [AppMode]. Persists to the `settings` Hive
/// box so the choice survives cold starts.
///
/// The cubit deliberately does NOT perform the GetIt scope swap or the
/// `Phoenix.rebirth` — that's the app root's job. Emitting a new mode is the
/// signal; the listener at the top of the widget tree picks it up and runs
/// `switchAppMode(...)`. Keeping the cubit BuildContext-free means callers
/// can write `context.read<AppModeCubit>().switchMode(...)` from anywhere
/// without threading a Navigator context through their callbacks.
class AppModeCubit extends Cubit<AppMode> {
  AppModeCubit(this._settings, {AnalyticsService Function()? analyticsLookup})
    : _analyticsLookup = analyticsLookup,
      super(_resolveBoot(_settings));

  final Box _settings;
  // Lazy lookup — AnalyticsService is registered AFTER this cubit in
  // the bootstrap order, so we can't capture an instance at construction
  // time. Reading via a closure defers resolution to the moment we
  // actually need to fire an event.
  final AnalyticsService Function()? _analyticsLookup;

  /// Hive key that mirrors the persisted mode. Kept as `app_mode` rather than
  /// `active_app_mode` to stay compatible with rows already written by older
  /// builds — switching keys would silently demote upgraded users back to
  /// customer on the first launch after rollout.
  static const String modeKey = 'app_mode';

  /// Cached seller approval flag. Updated whenever a profile fetch resolves
  /// (see [recordSellerApproval]). Lets us run the boot-time security guard
  /// synchronously — by the time `getInitialMode` is called, no network
  /// round-trip is available, so we lean on the previous session's snapshot.
  static const String sellerApprovedCacheKey = 'seller_approval_cached';

  /// Synchronous mirror of "is there a live Woody session". [AuthCubit] keeps
  /// it in sync (true on sign-in, false on sign-out / forced 401 logout) via
  /// [markSessionActive] / [demoteToCustomer]. The boot guard reads it so a
  /// cold start while logged out never lands on the seller surface — secure
  /// storage (where the real tokens live) is async-only and isn't available
  /// at the cubit's synchronous construction.
  static const String sessionActiveKey = 'session_active';

  /// Resolves the mode the app should boot into.
  ///
  /// Security guards, in order:
  ///   1. **Logged out** — if there's no live session, force `customer`. The
  ///      seller surface must never be reachable without auth, so a logged-out
  ///      cold start (manual or 401-forced sign-out) always boots to customer.
  ///   2. **Unapproved seller** — if Hive remembers `seller` but the cached
  ///      approval flag is false (banned, status reverted, or never approved
  ///      on this device), downgrade to `customer`.
  ///
  /// The persisted `modeKey` is left untouched in both cases so a re-login /
  /// re-approval restores the user's preference on the next launch without
  /// forcing them to re-flip the toggle.
  static AppMode _resolveBoot(Box settings) {
    final saved = AppMode.fromName(settings.get(modeKey) as String?);
    if (saved == AppMode.seller && !_readSessionActive(settings)) {
      return AppMode.customer;
    }
    if (saved == AppMode.seller && !_readApprovalCache(settings)) {
      return AppMode.customer;
    }
    return saved;
  }

  static bool _readApprovalCache(Box settings) =>
      (settings.get(sellerApprovedCacheKey) as bool?) ?? false;

  static bool _readSessionActive(Box settings) =>
      (settings.get(sessionActiveKey) as bool?) ?? false;

  Future<void> switchMode(AppMode mode) async {
    if (state == mode) return;
    await _settings.put(modeKey, mode.name);
    if (isClosed) return;
    emit(mode);
    // Funnel signal — track only the customer→seller flip; entering
    // customer mode is the implicit default and would be noise.
    try {
      final analytics = _analyticsLookup?.call();
      unawaited(analytics?.setUserProperty(name: 'app_mode', value: mode.name));
      if (mode == AppMode.seller) {
        unawaited(analytics?.sellerModeEntered());
      }
    } catch (_) {
      // Analytics resolution can fail in tests / no-Firebase builds —
      // silently swallow; mode switch must still go through.
    }
  }

  /// Re-reads Hive (running the same boot-time guard as the constructor) and
  /// emits the resolved mode. Used by [performLogout] after it has cleared
  /// the persisted keys and torn down the active scope manually — emitting
  /// without the listener's scope-swap is what we want there, because we've
  /// already swapped the scope ourselves.
  ///
  /// Safe to call when state is unchanged; the underlying [Cubit.emit] will
  /// no-op for an equal value.
  void syncFromHive() {
    emit(_resolveBoot(_settings));
  }

  /// Invoked when the live profile resolves. Two effects:
  ///   1. Caches the approval boolean so the next cold start can honor a
  ///      persisted `seller` mode without a network call.
  ///   2. If the user is currently in seller mode but no longer approved,
  ///      demotes them back to customer — the seller surface must not be
  ///      reachable once approval is revoked.
  Future<void> recordSellerApproval(bool isApproved) async {
    await _settings.put(sellerApprovedCacheKey, isApproved);
    if (state == AppMode.seller && !isApproved) {
      await _settings.put(modeKey, AppMode.customer.name);
      if (isClosed) return;
      emit(AppMode.customer);
    }
  }

  /// Records that a live session exists so the next cold start's boot guard
  /// can honor a persisted `seller` mode. Called by [AuthCubit] on sign-in.
  ///
  /// Also re-promotes to seller when the boot guard had demoted the *live*
  /// state purely because the session flag was missing/false at construction
  /// (the common case on the first launch after this flag was introduced, when
  /// no `sessionActiveKey` exists yet for an already-logged-in seller). The
  /// persisted preference is still `seller` and approval is cached, so once the
  /// session is confirmed we restore the user's chosen surface rather than
  /// silently leaving an approved seller on customer.
  Future<void> markSessionActive() async {
    await _settings.put(sessionActiveKey, true);
    if (isClosed) return;
    final persisted = AppMode.fromName(_settings.get(modeKey) as String?);
    if (state == AppMode.customer &&
        persisted == AppMode.seller &&
        _readApprovalCache(_settings)) {
      emit(AppMode.seller);
    }
  }

  /// Logout-driven demotion. Clears the session flag and, if the user is
  /// currently in seller mode, flips the persisted mode + emits `customer` so
  /// the root listener swaps the GetIt scope and `Phoenix.rebirth`s into the
  /// customer surface. Called by [AuthCubit] on every sign-out — both the
  /// manual logout and a 401-forced one — so the seller surface is never left
  /// standing behind a dead session.
  ///
  /// [performLogout] does its own scope teardown and key cleanup, so this is a
  /// no-op there beyond clearing the flag (state is already customer by then).
  Future<void> demoteToCustomer() async {
    await _settings.put(sessionActiveKey, false);
    if (state == AppMode.seller) {
      await _settings.put(modeKey, AppMode.customer.name);
      if (isClosed) return;
      emit(AppMode.customer);
    }
  }
}
