import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../customer/features/notifications/cubit/notifications_cubit.dart';
import '../../shared/mock/mock_address_repository.dart';
import '../../shared/mock/mock_banner_repository.dart';
import '../../shared/mock/mock_cart_repository.dart';
import '../../shared/mock/mock_category_repository.dart';
import '../../shared/mock/mock_favorites_repository.dart';
import '../../shared/mock/mock_notifications_repository.dart';
import '../../shared/mock/mock_order_repository.dart';
import '../../shared/mock/mock_product_repository.dart';
import '../../shared/mock/mock_region_repository.dart';
import '../../shared/mock/mock_shop_repository.dart';
import '../../shared/repositories/address_repository.dart';
import '../../shared/repositories/banner_repository.dart';
import '../../shared/repositories/cart_repository.dart';
import '../../shared/repositories/category_repository.dart';
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
import '../../shared/repositories/supabase_favorites_repository.dart';
import '../../shared/repositories/supabase_notifications_repository.dart';
import '../../shared/repositories/supabase_order_repository.dart';
import '../../shared/repositories/supabase_product_data_source.dart';
import '../storage/hive_boxes.dart';
import 'repository_resolver.dart';

/// Root-scope catalog + customer-shared repositories and data sources.
/// Every "which implementation" branch flows through [RepositoryResolver]
/// instead of hand-rolled `isRegistered<SupabaseClient>()` ternaries.
void registerCatalogModule(GetIt sl) {
  final resolver = RepositoryResolver.fromEnvironment(
    hasSupabase: sl.isRegistered<SupabaseClient>(),
  );

  // --- data sources (Supabase, or an offline mock — no Dio variant) --------
  sl.registerLazySingleton<CategoryDataSource>(
    () => resolver.resolveOrFallback<CategoryDataSource>(
      supabase: () =>
          SupabaseCategoryRepository(supabase: sl<SupabaseClient>()),
      fallback: MockCategoryDataSource.new,
    ),
  );
  sl.registerLazySingleton<SupabaseProductDataSource>(
    () => resolver.resolveOrFallback<SupabaseProductDataSource>(
      supabase: () => SupabaseProductRepository(supabase: sl<SupabaseClient>()),
      fallback: MockSupabaseProductDataSource.new,
    ),
  );
  sl.registerLazySingleton<NotificationDataSource>(
    () => resolver.resolveOrFallback<NotificationDataSource>(
      supabase: () =>
          SupabaseNotificationsRepository(supabase: sl<SupabaseClient>()),
      fallback: MockNotificationDataSource.new,
    ),
  );

  // NewsDataSource — public broadcast feed; only when Supabase is live.
  if (sl.isRegistered<SupabaseClient>()) {
    sl.registerLazySingleton<NewsDataSource>(
      () => SupabaseNewsRepository(
        supabase: sl<SupabaseClient>(),
        readsBox: sl<Box>(instanceName: HiveBoxes.newsReads),
      ),
    );
  }

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

  // --- catalog repositories (Supabase / mock / remote matrix) --------------
  sl.registerLazySingleton<ProductRepository>(
    () => resolver.resolve<ProductRepository>(
      mock: MockProductRepository.new,
      remote: () => RemoteProductRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<CategoryRepository>(
    () => resolver.resolve<CategoryRepository>(
      mock: MockCategoryRepository.new,
      remote: () => RemoteCategoryRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<ShopRepository>(
    () => resolver.resolve<ShopRepository>(
      mock: MockShopRepository.new,
      remote: () => RemoteShopRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<BannerRepository>(
    () => resolver.resolve<BannerRepository>(
      supabase: () => SupabaseBannerRepository(supabase: sl<SupabaseClient>()),
      mock: MockBannerRepository.new,
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
      mock: MockCartRepository.new,
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
      mock: MockFavoritesRepository.new,
      remote: () => RemoteFavoritesRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<RegionRepository>(
    () => resolver.resolve<RegionRepository>(
      mock: MockRegionRepository.new,
      remote: () => RemoteRegionRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<AddressRepository>(
    () => resolver.resolve<AddressRepository>(
      mock: MockAddressRepository.new,
      remote: () => RemoteAddressRepository(sl<Dio>()),
    ),
  );

  // OrderRepository — PRESERVED EXCEPTION (ROADMAP B.6 review note): unlike
  // every other repository here, a mock build ALWAYS uses MockOrderRepository
  // and never the Supabase implementation; only the non-mock build prefers
  // Supabase. Do NOT collapse this into `resolver.resolve(...)`, which is
  // Supabase-preferred and would change behaviour for mock builds.
  sl.registerLazySingleton<OrderRepository>(() {
    if (resolver.useMocks) return MockOrderRepository();
    return resolver.hasSupabase
        ? SupabaseOrderRepository(sl<SupabaseClient>())
        : RemoteOrderRepository(sl<Dio>());
  });

  sl.registerLazySingleton<NotificationsRepository>(
    () => resolver.resolve<NotificationsRepository>(
      mock: MockNotificationsRepository.new,
      remote: () => RemoteNotificationsRepository(sl<Dio>()),
    ),
  );
}
