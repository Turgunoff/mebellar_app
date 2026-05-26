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
import '../../shared/repositories/hive_cart_repository.dart';
import '../../shared/repositories/hive_favorites_repository.dart';
import '../../shared/repositories/hybrid_cart_repository.dart';
import '../../shared/repositories/hybrid_favorites_repository.dart';
import '../../shared/repositories/news_repository.dart';
import '../../shared/repositories/notifications_repository.dart';
import '../../shared/repositories/order_repository.dart';
import '../../shared/repositories/product_repository.dart';
import '../../shared/repositories/region_repository.dart';
import '../../shared/repositories/shop_repository.dart';
import '../../shared/repositories/supabase_banner_repository.dart';
import '../../shared/repositories/supabase_cart_repository.dart';
import '../../shared/repositories/supabase_category_repository.dart';
import '../../shared/repositories/supabase_customer_reviews_repository.dart';
import '../../shared/repositories/supabase_favorites_repository.dart';
import '../../shared/repositories/supabase_notifications_repository.dart';
import '../../shared/repositories/supabase_order_repository.dart';
import '../../shared/repositories/supabase_product_data_source.dart';
import '../../shared/repositories/woody_banner_repository.dart';
import '../../shared/repositories/woody_category_repository.dart';
import '../../shared/repositories/woody_chat_repositories.dart';
import '../../shared/repositories/woody_customer_repositories.dart';
import '../../shared/repositories/woody_product_repository.dart';
import '../network/woody_api_client.dart';
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

  CategoryDataSource buildCategoryDs() => useWoody
      ? WoodyCategoryRepository(api: sl<WoodyApiClient>())
      : SupabaseCategoryRepository(supabase: sl<SupabaseClient>());

  SupabaseProductDataSource buildProductDs() => useWoody
      ? WoodyProductRepository(api: sl<WoodyApiClient>())
      : SupabaseProductRepository(supabase: sl<SupabaseClient>());

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

    // Order-scoped chats — Woody REST when configured; Supabase fallback
    // for builds without a Woody backend (dev / tests).
    if (useWoody) {
      sl.registerLazySingleton<ChatRepository>(
        () => WoodyChatRepository(api: sl<WoodyApiClient>()),
      );
    } else if (sl.isRegistered<SupabaseClient>()) {
      sl.registerLazySingleton<ChatRepository>(
        () => SupabaseChatRepository(supabase: sl<SupabaseClient>()),
      );
    }
    // Notifications data source (`NotificationDataSource`) drives the
    // home inbox cubit and still reads from Supabase — Phase 8 wraps it
    // around the Woody endpoint once the cubit is rewired. The simpler
    // `NotificationsRepository` (below) is already on Woody.
    if (sl.isRegistered<SupabaseClient>()) {
      sl.registerLazySingleton<NotificationDataSource>(
        () => SupabaseNotificationsRepository(supabase: sl<SupabaseClient>()),
      );
    }

    // Customer-side product reviews — prefer Woody when configured.
    sl.registerLazySingleton<CustomerReviewsRepository>(
      () => useWoody
          ? WoodyCustomerReviewsRepository(api: sl<WoodyApiClient>())
          : SupabaseCustomerReviewsRepository(supabase: sl<SupabaseClient>()),
    );

    // NewsDataSource — public broadcast feed; only when Supabase is live.
    sl.registerLazySingleton<NewsDataSource>(
      () => SupabaseNewsRepository(
        supabase: sl<SupabaseClient>(),
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
      supabase: sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
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
      inner: useWoody
          ? WoodyBannerRepository(api: sl<WoodyApiClient>())
          : resolver.resolve<BannerRepository>(
              supabase: () =>
                  SupabaseBannerRepository(supabase: sl<SupabaseClient>()),
              remote: () => RemoteBannerRepository(sl<Dio>()),
            ),
      cache: sl<CacheStore>(),
    ),
  );
  // Woody mode talks to the backend directly — the offline-merge layer that
  // `HybridCartRepository` provides was tightly coupled to Supabase's auth
  // stream. `WoodyCartRepository` handles a signed-out caller gracefully
  // (returns an empty cart on 401), so the hybrid wrapper is unnecessary
  // here. Re-introducing Hive-backed offline guest carts on the Woody path
  // is a Phase 8 follow-up.
  sl.registerLazySingleton<CartRepository>(
    () => useWoody
        ? WoodyCartRepository(api: sl<WoodyApiClient>())
        : resolver.resolve<CartRepository>(
            supabase: () => HybridCartRepository(
              hive: HiveCartRepository(sl<Box>(instanceName: HiveBoxes.cart)),
              remote: SupabaseCartRepository(supabase: sl<SupabaseClient>()),
              supabase: sl<SupabaseClient>(),
            ),
            remote: () => RemoteCartRepository(sl<Dio>()),
          ),
  );
  sl.registerLazySingleton<FavoritesRepository>(
    () => useWoody
        ? WoodyFavoritesRepository(api: sl<WoodyApiClient>())
        : resolver.resolve<FavoritesRepository>(
            supabase: () => HybridFavoritesRepository(
              hive: HiveFavoritesRepository(
                sl<Box>(instanceName: HiveBoxes.favorites),
              ),
              remote: SupabaseFavoritesRepository(
                supabase: sl<SupabaseClient>(),
              ),
              supabase: sl<SupabaseClient>(),
            ),
            remote: () => RemoteFavoritesRepository(sl<Dio>()),
          ),
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
    () => useWoody
        ? WoodyOrderRepository(sl<WoodyApiClient>())
        : (resolver.hasSupabase
            ? SupabaseOrderRepository(sl<SupabaseClient>())
            : RemoteOrderRepository(sl<Dio>())),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => useWoody
        ? WoodyNotificationsRepository(api: sl<WoodyApiClient>())
        : resolver.resolve<NotificationsRepository>(
            remote: () => RemoteNotificationsRepository(sl<Dio>()),
          ),
  );
}
