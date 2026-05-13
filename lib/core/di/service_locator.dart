import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../config/app_mode.dart';
import '../../customer/features/cart/bloc/cart_bloc.dart';
import '../../customer/features/categories/bloc/categories_bloc.dart';
import '../../customer/features/favorites/bloc/favorites_bloc.dart';
import '../../customer/features/home/bloc/home_bloc.dart';
import '../../customer/features/notifications/cubit/notifications_cubit.dart';
import '../../customer/features/orders/cubit/profile_orders_cubit.dart';
import '../../customer/features/profile/cubit/profile_cubit.dart';
import '../../customer/services/order_tracking_service.dart';
import '../../seller/services/new_orders_listener.dart';
import '../../shared/mock/mock_address_repository.dart';
import '../../shared/mock/mock_banner_repository.dart';
import '../../shared/mock/mock_cart_repository.dart';
import '../../shared/mock/mock_category_repository.dart';
import '../../shared/mock/mock_favorites_repository.dart';
import '../../shared/mock/mock_notifications_repository.dart';
import '../../shared/mock/mock_order_repository.dart';
import '../../shared/mock/mock_product_repository.dart';
import '../../shared/mock/mock_region_repository.dart';
import '../../shared/mock/mock_regions.dart';
import '../../shared/mock/mock_seller_onboarding_repository.dart';
import '../../shared/repositories/supabase_seller_onboarding_repository.dart';
import '../../shared/mock/mock_seller_order_repository.dart';
import '../../shared/mock/mock_seller_product_repository.dart';
import '../../shared/mock/mock_seller_services_repository.dart';
import '../../shared/mock/mock_seller_verification_repository.dart';
import '../../shared/mock/mock_shop_repository.dart';
import '../../shared/mock/mock_shop_settings_repository.dart';
import '../../shared/mock/mock_tariff_repository.dart';
import '../../shared/repositories/address_repository.dart';
import '../../shared/repositories/banner_repository.dart';
import '../../shared/repositories/supabase_banner_repository.dart';
import '../../shared/repositories/cart_repository.dart';
import '../../shared/repositories/category_repository.dart';
import '../../shared/repositories/favorites_repository.dart';
import '../../shared/repositories/news_repository.dart';
import '../../shared/repositories/hive_cart_repository.dart';
import '../../shared/repositories/hive_favorites_repository.dart';
import '../../shared/repositories/hybrid_cart_repository.dart';
import '../../shared/repositories/hybrid_favorites_repository.dart';
import '../../shared/repositories/supabase_cart_repository.dart';
import '../../shared/repositories/supabase_category_repository.dart';
import '../../shared/repositories/supabase_favorites_repository.dart';
import '../../shared/repositories/supabase_product_data_source.dart';
import '../../shared/repositories/supabase_notifications_repository.dart';
import '../../shared/repositories/supabase_order_repository.dart';
import '../../shared/repositories/notifications_repository.dart';
import '../../shared/repositories/order_repository.dart';
import '../../shared/repositories/product_repository.dart';
import '../../shared/repositories/region_repository.dart';
import '../../shared/repositories/seller_dashboard_repository.dart';
import '../../shared/repositories/supabase_seller_dashboard_repository.dart';
import '../../seller/features/dashboard/bloc/seller_dashboard_cubit.dart';
import '../../shared/repositories/seller_onboarding_repository.dart';
import '../../shared/repositories/seller_order_repository.dart';
import '../../shared/repositories/seller_product_repository.dart';
import '../../shared/repositories/seller_services_repository.dart';
import '../../shared/repositories/seller_verification_repository.dart';
import '../../shared/repositories/shop_repository.dart';
import '../../shared/repositories/shop_settings_repository.dart';
import '../../shared/repositories/tariff_repository.dart';
import '../auth/app_mode_cubit.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_repository.dart';
import '../auth/sign_out.dart';
import '../connectivity/connectivity_service.dart';
import '../connectivity/network_cubit.dart';
import '../deep_links/deep_link_service.dart';
import '../network/api_client.dart';
import '../network/supabase_client.dart';
import '../notifications/notification_handler.dart';
import '../notifications/push_service.dart';
import '../storage/cache_store.dart';
import '../storage/hive_boxes.dart';
import '../storage/secure_storage.dart';
import '../theme/theme_cubit.dart';

final GetIt sl = GetIt.instance;

bool _rootInitialised = false;

/// Boots the singletons that survive every mode switch (Hive boxes, Supabase
/// client, Dio, AuthRepository, OneSignal handler placeholder, ...).
Future<void> initRootScope() async {
  if (_rootInitialised) return;

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
  sl.registerSingleton<Box>(
    boxes.favorites,
    instanceName: HiveBoxes.favorites,
  );
  sl.registerSingleton<Box>(
    boxes.cart,
    instanceName: HiveBoxes.cart,
  );
  sl.registerSingleton<Box>(
    boxes.newsReads,
    instanceName: HiveBoxes.newsReads,
  );

  sl.registerSingleton<ThemeCubit>(
    ThemeCubit(boxes.settings),
    dispose: (c) => c.close(),
  );

  // Reactive view over the persisted app mode. Survives mode switches because
  // it lives on the root scope; the mode-switch flow below emits new state on
  // it so widgets reading `BlocBuilder<AppModeCubit>` rebuild even when the
  // caller goes through `switchAppMode(...)` rather than `cubit.switchMode`.
  sl.registerSingleton<AppModeCubit>(
    AppModeCubit(boxes.settings),
    dispose: (c) => c.close(),
  );

  sl.registerSingleton<SecureStorage>(SecureStorage());

  // Connectivity supervisor. Real implementation combines `connectivity_plus`
  // (link state) + `internet_connection_checker_plus` (actual reachability).
  // Tests substitute MockConnectivityService via `sl.allowReassignment`.
  sl.registerSingleton<ConnectivityService>(
    RealConnectivityService(),
    dispose: (s) => s.dispose(),
  );
  // Wraps the connectivity stream as a Cubit so the global network overlay
  // banner can subscribe through `BlocListener` and survive route changes.
  sl.registerSingleton<NetworkCubit>(
    NetworkCubit(sl<ConnectivityService>()),
    dispose: (c) => c.close(),
  );
  // DeepLinkService doubles as the pending-route store used by the inbox
  // routing interceptor: cross-mode taps stash a path here, the rebuilt app
  // root consumes it on init. Backed by the shared `pending_route` Hive box
  // so the route survives `Phoenix.rebirth` (and cold starts triggered by
  // a tray push that flips `app_mode`).
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

  if (supabase != null) {
    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepository(sl<SupabaseClient>(), sl<Dio>()),
      dispose: (repo) => repo.dispose(),
    );
  }

  sl.registerLazySingleton<NotificationHandler>(
    () => NotificationHandler(sl<Box>(instanceName: HiveBoxes.pendingRoute)),
  );

  // FCM push handler. Initialised in `main.dart` after Firebase.initializeApp
  // — registration here only wires the dependency, no network calls happen
  // until `sl<PushService>().initialise()` is awaited.
  sl.registerLazySingleton<PushService>(
    () => PushService(
      messaging: FirebaseMessaging.instance,
      localNotifications: FlutterLocalNotificationsPlugin(),
      notificationHandler: sl<NotificationHandler>(),
      supabase: sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
    ),
  );

  // Single global auth listener — survives customer↔seller mode switches.
  sl.registerSingleton<AuthCubit>(
    AuthCubit(
      sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
    ),
    dispose: (c) => c.close(),
  );

  // CategoryDataSource — Supabase when available, mock otherwise.
  sl.registerLazySingleton<CategoryDataSource>(
    () => sl.isRegistered<SupabaseClient>()
        ? SupabaseCategoryRepository(supabase: sl<SupabaseClient>())
        : MockCategoryDataSource(),
  );

  // SupabaseProductDataSource — Supabase when available, mock otherwise.
  sl.registerLazySingleton<SupabaseProductDataSource>(
    () => sl.isRegistered<SupabaseClient>()
        ? SupabaseProductRepository(supabase: sl<SupabaseClient>())
        : MockSupabaseProductDataSource(),
  );

  // NotificationDataSource — backed by `public.notifications` when Supabase
  // is available; otherwise a small canned mock so the inbox renders.
  sl.registerLazySingleton<NotificationDataSource>(
    () => sl.isRegistered<SupabaseClient>()
        ? SupabaseNotificationsRepository(supabase: sl<SupabaseClient>())
        : MockNotificationDataSource(),
  );

  // NewsDataSource — public broadcast feed visible to anonymous users too.
  // Registered at root scope (not customer-scoped) because logging out
  // shouldn't tear down the news subscription — the same instance keeps
  // streaming for the now-anonymous session.
  if (sl.isRegistered<SupabaseClient>()) {
    sl.registerLazySingleton<NewsDataSource>(
      () => SupabaseNewsRepository(
        supabase: sl<SupabaseClient>(),
        readsBox: sl<Box>(instanceName: HiveBoxes.newsReads),
      ),
    );
  }

  // NotificationsCubit lives in the ROOT scope (not mode-scoped) so a single
  // instance feeds both the customer inbox + bell badge AND the seller inbox
  // + bell badge. Each screen filters by `kind.targetMode` locally — the
  // cubit always holds the union. Side benefits of root-scoping:
  //   * Realtime subscription survives customer↔seller mode switches, so an
  //     INSERT while the user is mid-rebirth isn't dropped.
  //   * The cross-mode routing interceptor can `markRead(...)` from one mode
  //     and the OTHER mode's badge reflects it on the next frame.
  sl.registerLazySingleton<NotificationsCubit>(
    () => NotificationsCubit(
      sl<NotificationDataSource>(),
      supabase:
          sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
      newsRepo:
          sl.isRegistered<NewsDataSource>() ? sl<NewsDataSource>() : null,
    )..load(),
    dispose: (c) => c.close(),
  );

  // Shared repositories — when AppConfig.useMocks is true, register the
  // canned in-memory implementations so the catalog UI works without a live
  // backend. Flip the flag in env/<env>.json once the API is ready.
  if (AppConfig.useMocks) {
    sl.registerLazySingleton<ProductRepository>(MockProductRepository.new);
    sl.registerLazySingleton<CategoryRepository>(MockCategoryRepository.new);
    sl.registerLazySingleton<ShopRepository>(MockShopRepository.new);
    sl.registerLazySingleton<BannerRepository>(
      () => sl.isRegistered<SupabaseClient>()
          ? SupabaseBannerRepository(supabase: sl<SupabaseClient>())
          : MockBannerRepository(),
    );
    sl.registerLazySingleton<CartRepository>(
      () => sl.isRegistered<SupabaseClient>()
          ? HybridCartRepository(
              hive: HiveCartRepository(
                sl<Box>(instanceName: HiveBoxes.cart),
              ),
              remote: SupabaseCartRepository(
                supabase: sl<SupabaseClient>(),
              ),
              supabase: sl<SupabaseClient>(),
            )
          : MockCartRepository(),
    );
    sl.registerLazySingleton<FavoritesRepository>(
      () => sl.isRegistered<SupabaseClient>()
          ? HybridFavoritesRepository(
              hive: HiveFavoritesRepository(
                sl<Box>(instanceName: HiveBoxes.favorites),
              ),
              remote: SupabaseFavoritesRepository(
                supabase: sl<SupabaseClient>(),
              ),
              supabase: sl<SupabaseClient>(),
            )
          : MockFavoritesRepository(),
    );
    sl.registerLazySingleton<RegionRepository>(MockRegionRepository.new);
    sl.registerLazySingleton<AddressRepository>(MockAddressRepository.new);
    sl.registerLazySingleton<OrderRepository>(MockOrderRepository.new);
    sl.registerLazySingleton<SellerOnboardingRepository>(
      () => sl.isRegistered<SupabaseClient>()
          ? SupabaseSellerOnboardingRepository(
              supabase: sl<SupabaseClient>(),
              draftBox: sl<Box>(instanceName: HiveBoxes.onboardingDraft),
            )
          : MockSellerOnboardingRepository(
              draftBox: sl<Box>(instanceName: HiveBoxes.onboardingDraft),
              findRegionById: MockRegions.findById,
            ),
    );
    sl.registerLazySingleton<SellerVerificationRepository>(
      MockSellerVerificationRepository.new,
    );
    sl.registerLazySingleton<SellerProductRepository>(
      MockSellerProductRepository.new,
    );
    // Dashboard is intentionally NOT mocked — we want every build (even
    // the mock-flagged dev builds) to read live shop/product/order data so
    // the empty-state experience is exercised by default. Requires Supabase
    // to be registered at root scope.
    sl.registerLazySingleton<SellerDashboardRepository>(
      () => SupabaseSellerDashboardRepository(sl<SupabaseClient>()),
    );
    sl.registerLazySingleton<SellerOrderRepository>(
      MockSellerOrderRepository.new,
    );
    sl.registerLazySingleton<ShopSettingsRepository>(
      MockShopSettingsRepository.new,
    );
    sl.registerLazySingleton<SellerServicesRepository>(
      MockSellerServicesRepository.new,
    );
    sl.registerLazySingleton<TariffRepository>(MockTariffRepository.new);
    sl.registerLazySingleton<NotificationsRepository>(
      MockNotificationsRepository.new,
    );
  } else {
    sl.registerLazySingleton<ProductRepository>(
      () => RemoteProductRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<CategoryRepository>(
      () => RemoteCategoryRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<ShopRepository>(
      () => RemoteShopRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<BannerRepository>(
      () => sl.isRegistered<SupabaseClient>()
          ? SupabaseBannerRepository(supabase: sl<SupabaseClient>())
          : RemoteBannerRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<CartRepository>(
      () => sl.isRegistered<SupabaseClient>()
          ? HybridCartRepository(
              hive: HiveCartRepository(
                sl<Box>(instanceName: HiveBoxes.cart),
              ),
              remote: SupabaseCartRepository(
                supabase: sl<SupabaseClient>(),
              ),
              supabase: sl<SupabaseClient>(),
            )
          : RemoteCartRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<FavoritesRepository>(
      () => sl.isRegistered<SupabaseClient>()
          ? HybridFavoritesRepository(
              hive: HiveFavoritesRepository(
                sl<Box>(instanceName: HiveBoxes.favorites),
              ),
              remote: SupabaseFavoritesRepository(
                supabase: sl<SupabaseClient>(),
              ),
              supabase: sl<SupabaseClient>(),
            )
          : RemoteFavoritesRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<RegionRepository>(
      () => RemoteRegionRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<AddressRepository>(
      () => RemoteAddressRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<OrderRepository>(
      () => sl.isRegistered<SupabaseClient>()
          ? SupabaseOrderRepository(sl<SupabaseClient>())
          : RemoteOrderRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<SellerOnboardingRepository>(
      () => sl.isRegistered<SupabaseClient>()
          ? SupabaseSellerOnboardingRepository(
              supabase: sl<SupabaseClient>(),
              draftBox: sl<Box>(instanceName: HiveBoxes.onboardingDraft),
            )
          : RemoteSellerOnboardingRepository(
              dio: sl<Dio>(),
              draftBox: sl<Box>(instanceName: HiveBoxes.onboardingDraft),
              findRegionById: (id) => null,
            ),
    );
    sl.registerLazySingleton<SellerVerificationRepository>(
      () => RemoteSellerVerificationRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<SellerProductRepository>(
      () => RemoteSellerProductRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<SellerDashboardRepository>(
      () => SupabaseSellerDashboardRepository(sl<SupabaseClient>()),
    );
    sl.registerLazySingleton<SellerOrderRepository>(
      () => RemoteSellerOrderRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<ShopSettingsRepository>(
      () => RemoteShopSettingsRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<SellerServicesRepository>(
      () => RemoteSellerServicesRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<TariffRepository>(
      () => RemoteTariffRepository(sl<Dio>()),
    );
    sl.registerLazySingleton<NotificationsRepository>(
      () => RemoteNotificationsRepository(sl<Dio>()),
    );
  }

  _rootInitialised = true;
}

Future<void> initModeScope(AppMode mode) async {
  sl.pushNewScope(scopeName: mode.name);
  switch (mode) {
    case AppMode.customer:
      _registerCustomerDependencies();
    case AppMode.seller:
      _registerSellerDependencies();
  }
}

void _registerCustomerDependencies() {
  sl.registerLazySingleton<HomeBloc>(
    () => HomeBloc(
      bannerRepo: sl<BannerRepository>(),
      productSource: sl<SupabaseProductDataSource>(),
      networkCubit: sl<NetworkCubit>(),
    )..add(const HomeRequested()),
    dispose: (bloc) => bloc.close(),
  );
  sl.registerLazySingleton<OrderTrackingService>(
    () => OrderTrackingService(
      sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
    ),
    dispose: (svc) => svc.dispose(),
  );
  // CartBloc + FavoritesBloc are mode-scoped singletons so the cart badge in
  // the bottom nav and the cart screen share state. Both rely on the
  // cart/favorites repositories which live on the root scope.
  sl.registerLazySingleton<CartBloc>(
    () => CartBloc(sl<CartRepository>())..add(const LoadCart()),
    dispose: (bloc) => bloc.close(),
  );
  sl.registerLazySingleton<FavoritesBloc>(
    () => FavoritesBloc(sl<FavoritesRepository>())
      ..add(const FavoritesRequested()),
    dispose: (bloc) => bloc.close(),
  );
  sl.registerLazySingleton<CategoriesBloc>(
    () => CategoriesBloc(
      sl<CategoryDataSource>(),
      networkCubit: sl<NetworkCubit>(),
    )..add(const CategoriesRequested()),
    dispose: (bloc) => bloc.close(),
  );
  sl.registerLazySingleton<ProfileOrdersCubit>(
    () => ProfileOrdersCubit(sl<SupabaseClient>()),
    dispose: (c) => c.close(),
  );
  sl.registerLazySingleton<ProfileCubit>(
    () => ProfileCubit(sl<SupabaseClient>()),
    dispose: (c) => c.close(),
  );
  // NotificationsCubit moved to root scope (see initRootScope) so seller
  // mode can subscribe to the same instance — keep this customer init
  // free of notification wiring.
}

void _registerSellerDependencies() {
  sl.registerLazySingleton<NewOrdersListener>(
    () => NewOrdersListener(
      sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
    ),
    dispose: (svc) => svc.dispose(),
  );
  sl.registerFactory<SellerDashboardCubit>(
    () => SellerDashboardCubit(sl<SellerDashboardRepository>()),
  );
  // Sprint 7+: seller BLoC factories (DashboardBloc, SellerProductsBloc, ...)
  // land here.
}

/// Returns the mode the app should boot into. Delegates to [AppModeCubit] so
/// the same security guard (downgrade to customer if Hive says `seller` but
/// cached approval is false) runs both at cold start and after a Phoenix
/// rebirth — `_ModeRouter` re-reads this and re-creates the AppModeCubit
/// after rebirth, so the resolution stays consistent.
AppMode getInitialMode() => sl<AppModeCubit>().state;

/// Compatibility wrapper around [AppModeCubit.switchMode]. The actual scope
/// swap + Phoenix.rebirth happens in the root-level `BlocListener<AppModeCubit>`
/// installed in `main.dart`, which is now the single owner of that flow —
/// having two paths racing on `popScope()` produced intermittent disposal
/// failures, so all callers funnel through the cubit.
///
/// The [context] argument is retained for source compatibility with existing
/// callsites (e.g. seller profile "Xaridor rejimi" item) and is currently
/// unused; the listener uses its own Phoenix context.
Future<void> switchAppMode(BuildContext context, AppMode newMode) async {
  await sl<AppModeCubit>().switchMode(newMode);
}

/// Sign-out flow: clear cache, drop the saved mode (so next login defaults to
/// customer), tear down the active mode scope and reboot the widget tree.
Future<void> performLogout(BuildContext context) async {
  // Token cleanup runs as part of `signOutWithPushCleanup` below. The
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
  // `cubit.switchMode(...)`. Two reasons: (1) logout must clear scope
  // singletons even when the user is already in customer mode (so cubits
  // holding stale auth-derived state are disposed); cubit's no-op-on-same
  // state would skip that. (2) Bypassing the cubit means the root-level
  // mode-swap listener doesn't fire here and race with our pop/push pair.
  await sl.popScope();
  await initModeScope(AppMode.customer);
  // Sync the cubit so widgets observing it see `customer` post-logout, but
  // do it via the protected emit equivalent — we already swapped the scope
  // above, so a redundant emit→listener round-trip would double-pop.
  sl<AppModeCubit>().syncFromHive();
  if (context.mounted) {
    Phoenix.rebirth(context);
  }
}
