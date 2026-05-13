import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/app_mode.dart';

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
  AppModeCubit(this._settings) : super(_resolveBoot(_settings));

  final Box _settings;

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

  /// Resolves the mode the app should boot into.
  ///
  /// Security guard: if Hive remembers `seller` but the cached approval flag
  /// is false (banned, status reverted, or never approved on this device),
  /// downgrade to `customer` for this session. The persisted `modeKey` is
  /// left untouched so a re-approval restores the user's preference on the
  /// next launch without forcing them to re-flip the toggle.
  static AppMode _resolveBoot(Box settings) {
    final saved = AppMode.fromName(settings.get(modeKey) as String?);
    if (saved == AppMode.seller && !_readApprovalCache(settings)) {
      return AppMode.customer;
    }
    return saved;
  }

  static bool _readApprovalCache(Box settings) =>
      (settings.get(sellerApprovedCacheKey) as bool?) ?? false;

  Future<void> switchMode(AppMode mode) async {
    if (state == mode) return;
    await _settings.put(modeKey, mode.name);
    emit(mode);
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
      emit(AppMode.customer);
    }
  }
}
