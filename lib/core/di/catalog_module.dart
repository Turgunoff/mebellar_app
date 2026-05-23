import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../customer/features/notifications/cubit/notifications_cubit.dart';
import '../analytics/analytics_service.dart';
import '../analytics/firebase_analytics_service.dart';
import '../analytics/noop_analytics_service.dart';
import '../../shared/repositories/address_repository.dart';
import '../../shared/repositories/banner_repository.dart';
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

  // --- data sources (Supabase-only — no offline fallback) ------------------
  // The customer-facing catalog data sources are Supabase-only: production
  // never boots without `SUPABASE_URL` (see `AppConfig.assertConfigured`),
  // so a fallback would only mask a misconfigured build.
  if (sl.isRegistered<SupabaseClient>()) {
    sl.registerLazySingleton<CategoryDataSource>(
      () => SupabaseCategoryRepository(supabase: sl<SupabaseClient>()),
    );
    sl.registerLazySingleton<SupabaseProductDataSource>(
      () => SupabaseProductRepository(supabase: sl<SupabaseClient>()),
    );

    // Order-scoped chats — Supabase-only because chat hinges on RLS
    // (only the customer + shop owner can read a row) and there is no
    // offline write path. A mock falls in only for the no-Supabase build.
    sl.registerLazySingleton<ChatRepository>(
      () => SupabaseChatRepository(supabase: sl<SupabaseClient>()),
    );
    sl.registerLazySingleton<NotificationDataSource>(
      () => SupabaseNotificationsRepository(supabase: sl<SupabaseClient>()),
    );

    // Customer-side product reviews (write on delivered orders, read on the
    // product page). Supabase-only — there is no offline review flow.
    sl.registerLazySingleton<CustomerReviewsRepository>(
      () => SupabaseCustomerReviewsRepository(supabase: sl<SupabaseClient>()),
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
  sl.registerLazySingleton<AnalyticsService>(
    () {
      try {
        return FirebaseAnalyticsService();
      } catch (_) {
        return const NoopAnalyticsService();
      }
    },
  );

  // NotificationsCubit lives in the ROOT scope so a single instance feeds
  // both the customer inbox + bell badge AND the seller inbox + bell badge,
  // and the realtime subscription survives mode switches.
  sl.registerLazySingleton<NotificationsCubit>(
    () => NotificationsCubit(
      sl<NotificationDataSource>(),
      supabase:
          sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
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
    () => resolver.resolve<BannerRepository>(
      supabase: () => SupabaseBannerRepository(supabase: sl<SupabaseClient>()),
      remote: () => RemoteBannerRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<CartRepository>(
    () => resolver.resolve<CartRepository>(
      supabase: () => HybridCartRepository(
        hive: HiveCartRepository(sl<Box>(instanceName: HiveBoxes.cart)),
        remote: SupabaseCartRepository(supabase: sl<SupabaseClient>()),
        supabase: sl<SupabaseClient>(),
      ),
      remote: () => RemoteCartRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<FavoritesRepository>(
    () => resolver.resolve<FavoritesRepository>(
      supabase: () => HybridFavoritesRepository(
        hive:
            HiveFavoritesRepository(sl<Box>(instanceName: HiveBoxes.favorites)),
        remote: SupabaseFavoritesRepository(supabase: sl<SupabaseClient>()),
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
    () => resolver.hasSupabase
        ? SupabaseOrderRepository(sl<SupabaseClient>())
        : RemoteOrderRepository(sl<Dio>()),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => resolver.resolve<NotificationsRepository>(
      remote: () => RemoteNotificationsRepository(sl<Dio>()),
    ),
  );
}
