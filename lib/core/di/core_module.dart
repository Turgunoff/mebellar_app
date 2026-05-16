import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/app_mode_cubit.dart';
import '../connectivity/connectivity_service.dart';
import '../connectivity/network_cubit.dart';
import '../deep_links/deep_link_service.dart';
import '../network/api_client.dart';
import '../network/supabase_client.dart';
import '../realtime/realtime_service.dart';
import '../storage/app_settings.dart';
import '../storage/cache_store.dart';
import '../storage/hive_boxes.dart';
import '../storage/secure_storage.dart';
import '../theme/theme_cubit.dart';

/// Root-scope bootstrap: Hive boxes, the Supabase client, Dio, and the
/// cross-cutting services that survive every customer<->seller mode switch.
///
/// Must run before [registerAuthModule] / [registerCatalogModule] /
/// [registerSellerModule] — they all read `SupabaseClient` / `Dio` / boxes
/// registered here.
Future<void> registerCoreModule(GetIt sl) async {
  final boxes = await openCoreBoxes();
  sl.registerSingleton<Box>(boxes.settings, instanceName: HiveBoxes.settings);
  sl.registerSingleton<Box>(boxes.cache, instanceName: HiveBoxes.cache);
  sl.registerSingleton<Box>(
    boxes.pendingRoute,
    instanceName: HiveBoxes.pendingRoute,
  );
  sl.registerSingleton<Box>(
    boxes.onboardingDraft,
    instanceName: HiveBoxes.onboardingDraft,
  );
  sl.registerSingleton<Box>(boxes.favorites, instanceName: HiveBoxes.favorites);
  sl.registerSingleton<Box>(boxes.cart, instanceName: HiveBoxes.cart);
  sl.registerSingleton<Box>(boxes.newsReads, instanceName: HiveBoxes.newsReads);

  // ROADMAP B.6 — typed facade over the `settings` box; replaces scattered
  // magic-string Hive keys. Cubits migrate onto it incrementally.
  sl.registerSingleton<AppSettings>(AppSettings(boxes.settings));

  sl.registerSingleton<ThemeCubit>(
    ThemeCubit(boxes.settings),
    dispose: (c) => c.close(),
  );

  // Reactive view over the persisted app mode. Root-scoped so it survives
  // mode switches — the mode-switch listener emits new state on it.
  sl.registerSingleton<AppModeCubit>(
    AppModeCubit(boxes.settings),
    dispose: (c) => c.close(),
  );

  sl.registerSingleton<SecureStorage>(SecureStorage());

  // Connectivity supervisor. Tests substitute MockConnectivityService via
  // `sl.allowReassignment`.
  sl.registerSingleton<ConnectivityService>(
    RealConnectivityService(),
    dispose: (s) => s.dispose(),
  );
  sl.registerSingleton<NetworkCubit>(
    NetworkCubit(sl<ConnectivityService>()),
    dispose: (c) => c.close(),
  );

  // DeepLinkService doubles as the pending-route store for the cross-mode
  // routing interceptor; backed by the `pending_route` Hive box.
  sl.registerSingleton<DeepLinkService>(
    MockDeepLinkService(
      pendingRouteBox: sl<Box>(instanceName: HiveBoxes.pendingRoute),
    ),
    dispose: (s) => s.dispose(),
  );

  sl.registerLazySingleton<CacheStore>(
    () => CacheStore(sl<Box>(instanceName: HiveBoxes.cache)),
  );

  final supabase = await initSupabase();
  if (supabase != null) {
    sl.registerSingleton<SupabaseClient>(supabase);
  }

  sl.registerLazySingleton<Dio>(
    buildDioClient,
    dispose: (dio) => dio.close(force: true),
  );

  // ROADMAP B.6 — standardised realtime channel lifecycle. Holds the
  // (nullable) client so offline builds get an inert, leak-free instance;
  // `disposeAll` is wired straight into the scope dispose callback.
  sl.registerSingleton<RealtimeService>(
    RealtimeService(supabase),
    dispose: (s) => s.disposeAll(),
  );
}
