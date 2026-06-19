import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../analytics/analytics_service.dart';
import '../auth/app_mode_cubit.dart';
import '../cache/app_cache_cubit.dart';
import '../cache/cache_service.dart';
import '../connectivity/connectivity_service.dart';
import '../connectivity/network_cubit.dart';
import '../deep_links/deep_link_service.dart';
import '../../config/app_config.dart';
import '../i18n/app_locale_controller.dart';
import '../network/mock_payme_client.dart';
import '../network/payme_client.dart';
import '../network/token_store.dart';
import '../network/woody_api_client.dart';
import '../platform/location_facade.dart';
import '../realtime/woody_realtime_service.dart';
import '../storage/r2_upload_client.dart';
import '../storage/app_settings.dart';
import '../storage/cache_store.dart';
import '../storage/hive_boxes.dart';
import '../storage/secure_storage.dart';
import '../theme/theme_cubit.dart';

/// Root-scope bootstrap: Hive boxes, the Woody API client, Dio, and the
/// cross-cutting services that survive every customer<->seller mode switch.
///
/// Must run before [registerAuthModule] / [registerCatalogModule] /
/// [registerSellerModule] — they all read `WoodyApiClient` / `Dio` / boxes
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

  // The active-locale source of truth. Root-scoped (instead of a main.dart
  // local) so the API client can stamp `Accept-Language` on every request,
  // catalog caches can key snapshots per language, and long-lived blocs can
  // silently re-fetch on a language switch (see LocaleRefetch). main.dart
  // resolves this same instance for the MaterialApps.
  sl.registerSingleton<AppLocaleController>(
    AppLocaleController.fromBox(boxes.settings),
    dispose: (c) => c.dispose(),
  );

  sl.registerSingleton<ThemeCubit>(
    ThemeCubit(sl<AppSettings>()),
    dispose: (c) => c.close(),
  );

  // Shared, root-scoped owner of the disposable-cache size/clear flow. One
  // instance drives both the customer and seller settings screens. The
  // service it wraps only touches the temp dir + image caches — never secure
  // storage, tokens, or Hive boxes.
  sl.registerLazySingleton<CacheService>(() => const DefaultCacheService());
  sl.registerSingleton<AppCacheCubit>(
    AppCacheCubit(sl<CacheService>()),
    dispose: (c) => c.close(),
  );

  // Reactive view over the persisted app mode. Root-scoped so it survives
  // mode switches — the mode-switch listener emits new state on it.
  // Analytics is wired via a lookup closure because it's registered by a
  // later module — the cubit captures the closure now, resolves it lazily
  // when a mode change actually happens.
  sl.registerSingleton<AppModeCubit>(
    AppModeCubit(boxes.settings, analyticsLookup: () => sl<AnalyticsService>()),
    dispose: (c) => c.close(),
  );

  sl.registerSingleton<SecureStorage>(SecureStorage());

  // Woody backend (api.woody.uz) plumbing. TokenStore holds the
  // access/refresh pair in flutter_secure_storage; WoodyApiClient wraps a
  // dedicated Dio with a 401-triggered refresh interceptor. Both are
  // root-scoped so they survive customer<->seller mode swaps.
  sl.registerSingleton<TokenStore>(TokenStore(), dispose: (s) => s.dispose());
  sl.registerSingleton<WoodyApiClient>(
    WoodyApiClient(
      tokens: sl<TokenStore>(),
      locale: () => sl<AppLocaleController>().value.languageCode,
    ),
    dispose: (c) => c.dispose(),
  );

  // R2 presigned-PUT upload client. Single instance shared by every
  // feature that needs to push bytes (product images, chat attachments,
  // KYC docs, tariff receipts).
  sl.registerLazySingleton<R2UploadClient>(
    () => R2UploadClient(api: sl<WoodyApiClient>()),
  );

  // Payme Subscribe API client — talks DIRECTLY to Payme (X-Auth: merchant_id)
  // to tokenise + OTP-verify cards, so the raw PAN never reaches the backend.
  // Root-scoped (used by the add-card flow in customer mode); only ever
  // exercised when AppConfig.hasPayme — the UI is gated on that.
  // PAYME_MOCK swaps in a credential-free fake so the whole flow runs in a demo.
  sl.registerLazySingleton<PaymeClient>(
    () => AppConfig.paymeMock ? MockPaymeClient() : PaymeClient(),
    dispose: (c) => c.dispose(),
  );

  // Location facade — wraps geolocator's static API behind an injectable
  // seam (ROADMAP B.5). Tests substitute a fake via `sl.allowReassignment`.
  sl.registerSingleton<LocationFacade>(const GeolocatorLocationFacade());

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
    () => CacheStore(
      sl<Box>(instanceName: HiveBoxes.cache),
      localeOf: () => sl<AppLocaleController>().value.languageCode,
    ),
  );

  // Woody WebSocket realtime (Phase 6). Lazy — only opens when the auth
  // layer calls `start()` post sign-in. Singleton so feature subscribers
  // share the same connection.
  sl.registerSingleton<WoodyRealtimeService>(
    WoodyRealtimeService(tokens: sl<TokenStore>()),
    dispose: (s) => s.dispose(),
  );
}
