import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../customer/features/notifications/cubit/notifications_cubit.dart';
import '../analytics/analytics_service.dart';
import '../analytics/firebase_analytics_service.dart';
import '../analytics/noop_analytics_service.dart';
import '../../shared/repositories/address_repository.dart';
import '../../shared/repositories/banner_repository.dart';
import '../../shared/repositories/cached_banner_repository.dart';
import '../../shared/repositories/cached_category_repository.dart';
import '../../shared/repositories/cached_product_data_source.dart';
import '../../shared/repositories/cart_repository.dart';
import '../../shared/repositories/category_repository.dart';
import '../../shared/repositories/chat_repository.dart';
import '../../shared/repositories/customer_reviews_repository.dart';
import '../../shared/repositories/favorites_repository.dart';
import '../../shared/repositories/news_repository.dart';
import '../../shared/repositories/notifications_repository.dart';
import '../../shared/repositories/order_repository.dart';
import '../../shared/repositories/product_repository.dart';
import '../../shared/repositories/region_repository.dart';
import '../../shared/repositories/shop_repository.dart';
import '../../shared/repositories/supabase_category_repository.dart';
import '../../shared/repositories/supabase_notifications_repository.dart';
import '../../shared/repositories/supabase_product_data_source.dart';
import '../../shared/repositories/woody_banner_repository.dart';
import '../../shared/repositories/woody_category_repository.dart';
import '../../shared/repositories/woody_chat_repositories.dart';
import '../../shared/repositories/woody_customer_repositories.dart';
import '../../shared/repositories/woody_product_repository.dart';
import '../auth/auth_repository.dart';
import '../network/woody_api_client.dart';
import '../realtime/woody_realtime_service.dart';
import '../storage/cache_store.dart';
import '../storage/hive_boxes.dart';
import 'repository_resolver.dart';

/// Root-scope catalog + customer-shared repositories and data sources.
///
/// Every read goes against Supabase when a client was produced at boot
/// (`AppConfig.assertConfigured` makes that the only legal production
/// state). The legacy Dio/REST `Remote*` variants stay as the fallback for
/// builds without a Supabase client — a state that should never reach
/// production but is exercised by integration tests that construct a Dio
/// without a backing project.
void registerCatalogModule(GetIt sl) {
  final resolver = RepositoryResolver.fromEnvironment(
    hasSupabase: sl.isRegistered<SupabaseClient>(),
  );

  // Prefer the woody_backend REST surface when configured; fall back to
  // Supabase repositories during the migration window. The Woody-backed
  // repos return the same PostgREST-shaped payloads, so the cache-aside
  // decorators below see no change in payload shape either.
  final useWoody = AppConfig.hasWoodyApi;

  CategoryDataSource buildCategoryDs() =>
      WoodyCategoryRepository(api: sl<WoodyApiClient>());

  SupabaseProductDataSource buildProductDs() =>
      WoodyProductRepository(api: sl<WoodyApiClient>());

  // --- data sources (Supabase-only — no offline fallback) ------------------
  // The customer-facing catalog data sources are Supabase-only: production
  // never boots without `SUPABASE_URL` (see `AppConfig.assertConfigured`),
  // so a fallback would only mask a misconfigured build.
  if (sl.isRegistered<SupabaseClient>() || useWoody) {
    // Categories + recommended products + banners are wrapped in cache-aside
    // decorators so the home shell hydrates from Hive at 0 ms on every cold
    // start (see CachedCategoryRepository / CachedProductDataSource /
    // CachedBannerRepository for TTLs and the rationale per call). The
    // underlying Woody (or Supabase) repos still run — the decorator just
    // adds a write-through layer + a synchronous peek() entry point.
    sl.registerLazySingleton<CategoryDataSource>(
      () => CachedCategoryRepository(
        inner: buildCategoryDs(),
        cache: sl<CacheStore>(),
      ),
    );
    sl.registerLazySingleton<SupabaseProductDataSource>(
      () => CachedProductDataSource(
        inner: buildProductDs(),
        cache: sl<CacheStore>(),
      ),
    );

    // Order-scoped chats — Woody REST.
    sl.registerLazySingleton<ChatRepository>(
      () => WoodyChatRepository(api: sl<WoodyApiClient>()),
    );
    // Notifications inbox data source — Woody REST (`/notifications`).
    sl.registerLazySingleton<NotificationDataSource>(
      () => WoodyNotificationDataSource(api: sl<WoodyApiClient>()),
    );

    // Customer-side product reviews — Woody REST.
    sl.registerLazySingleton<CustomerReviewsRepository>(
      () => WoodyCustomerReviewsRepository(api: sl<WoodyApiClient>()),
    );

    // NewsDataSource — public broadcast feed; only when Supabase is live.
    sl.registerLazySingleton<NewsDataSource>(
      () => WoodyNewsRepository(
        api: sl<WoodyApiClient>(),
        readsBox: sl<Box>(instanceName: HiveBoxes.newsReads),
      ),
    );
  }

  // Analytics — Firebase-backed when the SDK initialised cleanly at boot,
  // a no-op otherwise so call sites never need to null-check. Lives in the
  // root scope: events from customer/seller modes both fan into one sink.
  sl.registerLazySingleton<AnalyticsService>(() {
    try {
      return FirebaseAnalyticsService();
    } catch (_) {
      return const NoopAnalyticsService();
    }
  });

  // NotificationsCubit lives in the ROOT scope so a single instance feeds
  // both the customer inbox + bell badge AND the seller inbox + bell badge,
  // and the realtime subscription survives mode switches.
  sl.registerLazySingleton<NotificationsCubit>(
    () => NotificationsCubit(
      sl<NotificationDataSource>(),
      realtime: sl.isRegistered<WoodyRealtimeService>()
          ? sl<WoodyRealtimeService>()
          : null,
      auth: sl.isRegistered<AuthRepository>() ? sl<AuthRepository>() : null,
      newsRepo: sl.isRegistered<NewsDataSource>() ? sl<NewsDataSource>() : null,
    )..load(),
    dispose: (c) => c.close(),
  );

  // --- catalog repositories (Supabase or legacy REST) ----------------------
  sl.registerLazySingleton<ProductRepository>(
    () => resolver.resolve<ProductRepository>(
      remote: () => RemoteProductRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<CategoryRepository>(
    () => resolver.resolve<CategoryRepository>(
      remote: () => RemoteCategoryRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<ShopRepository>(
    () => resolver.resolve<ShopRepository>(
      remote: () => RemoteShopRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<BannerRepository>(
    () => CachedBannerRepository(
      inner: WoodyBannerRepository(api: sl<WoodyApiClient>()),
      cache: sl<CacheStore>(),
    ),
  );
  // `WoodyCartRepository` talks to the backend directly and handles a
  // signed-out caller gracefully (empty cart on 401). Hive-backed offline
  // guest carts on the Woody path are a future follow-up.
  sl.registerLazySingleton<CartRepository>(
    () => WoodyCartRepository(api: sl<WoodyApiClient>()),
  );
  sl.registerLazySingleton<FavoritesRepository>(
    () => WoodyFavoritesRepository(api: sl<WoodyApiClient>()),
  );
  sl.registerLazySingleton<RegionRepository>(
    () => resolver.resolve<RegionRepository>(
      remote: () => RemoteRegionRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<AddressRepository>(
    () => resolver.resolve<AddressRepository>(
      remote: () => RemoteAddressRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<OrderRepository>(
    () => WoodyOrderRepository(sl<WoodyApiClient>()),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => WoodyNotificationsRepository(api: sl<WoodyApiClient>()),
  );
}
