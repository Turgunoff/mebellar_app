import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_mode.dart';
import '../auth/app_mode_cubit.dart';
import '../auth/sign_out.dart';
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

/// Sign-out flow: clear cache, drop the saved mode (so next login defaults to
/// customer), tear down the active mode scope and reboot the widget tree.
Future<void> performLogout(BuildContext context) async {
  // Token cleanup runs as part of `signOutWithPushCleanup`. The
  // AuthRepository wrapper is bypassed here so we don't double-call signOut.
  if (sl.isRegistered<SupabaseClient>()) {
    await signOutWithPushCleanup(sl<SupabaseClient>());
  }
  await sl<Box>(instanceName: HiveBoxes.cache).clear();
  await sl<Box>(instanceName: HiveBoxes.settings).delete(AppModeCubit.modeKey);
  // Clear the cached approval flag too — the next user signing in on this
  // device must not inherit the previous user's seller authorization.
  await sl<Box>(instanceName: HiveBoxes.settings)
      .delete(AppModeCubit.sellerApprovedCacheKey);
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
