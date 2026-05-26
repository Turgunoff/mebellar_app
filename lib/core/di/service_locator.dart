import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/app_mode.dart';
import '../auth/app_mode_cubit.dart';
import '../auth/auth_repository.dart';
import '../auth/sign_out.dart';
import '../logging/talker.dart';
import '../storage/hive_boxes.dart';
import 'auth_module.dart';
import 'catalog_module.dart';
import 'core_module.dart';
import 'scope_module.dart';
import 'seller_module.dart';

/// Global service locator.
///
/// ROADMAP B.6 — the ~600-line monolithic registration block was split into
/// focused modules (`core_module`, `auth_module`, `catalog_module`,
/// `seller_module`, `scope_module`). This file now only *orchestrates* them
/// and owns the mode-switch lifecycle (`getInitialMode` / `switchAppMode` /
/// `performLogout`).
final GetIt sl = GetIt.instance;

bool _rootInitialised = false;

/// Boots the singletons that survive every mode switch. Each module is
/// additive and ordered: [registerCoreModule] must run first because the
/// others read the `SupabaseClient` / `Dio` / Hive boxes it registers.
Future<void> initRootScope() async {
  if (_rootInitialised) return;

  await registerCoreModule(sl);
  registerAuthModule(sl);
  registerCatalogModule(sl);
  registerSellerModule(sl);

  _rootInitialised = true;
}

/// Pushes a new GetIt scope for [mode] and registers its mode-scoped blocs.
Future<void> initModeScope(AppMode mode) async {
  sl.pushNewScope(scopeName: mode.name);
  switch (mode) {
    case AppMode.customer:
      registerCustomerScope(sl);
    case AppMode.seller:
      registerSellerScope(sl);
  }
}

/// Returns the mode the app should boot into. Delegates to [AppModeCubit] so
/// the same security guard runs at cold start and after a Phoenix rebirth.
AppMode getInitialMode() => sl<AppModeCubit>().state;

/// Compatibility wrapper around [AppModeCubit.switchMode]. The actual scope
/// swap + `Phoenix.rebirth` happens in the root-level
/// `BlocListener<AppModeCubit>` installed in `main.dart`. The [context]
/// argument is retained for source compatibility and is currently unused.
Future<void> switchAppMode(BuildContext context, AppMode newMode) async {
  await sl<AppModeCubit>().switchMode(newMode);
}

/// Sign-out flow: clear every user-specific persistence surface, tear down
/// the active mode scope, and reboot the widget tree.
///
/// "Complete" cleanup — nothing the previous user touched survives:
///   * Supabase session + FCM token (`signOutWithPushCleanup`).
///   * Per-user Hive boxes (`cache`, `cart`, `favorites`, `onboardingDraft`,
///     `newsReads`, `pendingRoute`) are fully wiped. The `settings` box
///     keeps device-wide prefs (theme, language) but drops the two keys
///     that grant seller authority on the next cold start.
///   * `CachedNetworkImage`'s on-disk cache + Flutter's in-memory image
///     cache (avatars, product photos, KYC docs) are flushed so a different
///     user signing in on the device never sees a cached frame from the
///     previous account.
///   * Active mode scope is popped and re-pushed as customer so every
///     scope-scoped bloc/repo is rebuilt against the fresh (anonymous)
///     auth state.
Future<void> performLogout(BuildContext context) async {
  // Token cleanup runs as part of `signOutWithPushCleanup` (FCM token first
  // so the DELETE goes out while we're still authenticated, then the
  // access/refresh pair is wiped from TokenStore).
  if (sl.isRegistered<AuthRepository>()) {
    await signOutWithPushCleanup(sl<AuthRepository>());
  }

  // Every user-specific Hive box is wiped. Each `clear()` is independent —
  // a corrupt or missing box must not block the rest of the teardown, so we
  // log + continue. Order doesn't matter; nothing here cross-references.
  for (final boxName in const [
    HiveBoxes.cache,
    HiveBoxes.cart,
    HiveBoxes.favorites,
    HiveBoxes.onboardingDraft,
    HiveBoxes.newsReads,
    HiveBoxes.pendingRoute,
  ]) {
    try {
      await sl<Box>(instanceName: boxName).clear();
    } catch (e, st) {
      talker.handle(e, st, 'performLogout: clear $boxName failed');
    }
  }

  // The `settings` box is shared with device-wide prefs (theme, language)
  // that should outlive a sign-out, so we delete only the keys that gate
  // seller access. `modeKey` resets the default landing surface; the
  // approval cache prevents the next user inheriting the previous
  // seller's authorization at cold start (see [AppModeCubit._resolveBoot]).
  final settings = sl<Box>(instanceName: HiveBoxes.settings);
  await settings.delete(AppModeCubit.modeKey);
  await settings.delete(AppModeCubit.sellerApprovedCacheKey);

  // Drop the image caches so cached avatars / product photos / KYC docs
  // from the previous account never paint for the next user.
  // `DefaultCacheManager` owns the on-disk file cache that backs
  // `CachedNetworkImage`; `PaintingBinding.imageCache` is the in-memory
  // decoded-bitmap LRU.
  try {
    await DefaultCacheManager().emptyCache();
  } catch (e, st) {
    talker.handle(e, st, 'performLogout: image cache flush failed');
  }
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();

  // Tear down the active scope ourselves rather than going through
  // `cubit.switchMode(...)`: logout must clear scope singletons even when the
  // user is already in customer mode, and bypassing the cubit means the
  // root-level mode-swap listener doesn't race with our pop/push pair.
  await sl.popScope();
  await initModeScope(AppMode.customer);
  // Sync the cubit so widgets observing it see `customer` post-logout.
  sl<AppModeCubit>().syncFromHive();
  if (context.mounted) {
    Phoenix.rebirth(context);
  }
}
