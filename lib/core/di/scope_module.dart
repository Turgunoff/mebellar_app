import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../analytics/analytics_service.dart';
import '../../customer/features/cart/bloc/cart_bloc.dart';
import '../../customer/features/categories/bloc/categories_bloc.dart';
import '../../customer/features/favorites/bloc/favorites_bloc.dart';
import '../../customer/features/home/bloc/home_bloc.dart';
import '../../customer/features/orders/cubit/profile_orders_cubit.dart';
import '../../customer/features/profile/cubit/profile_cubit.dart';
import '../../customer/services/order_tracking_service.dart';
import '../../seller/features/dashboard/bloc/seller_dashboard_cubit.dart';
import '../../seller/features/orders/bloc/seller_orders_bloc.dart';
import '../../seller/features/profile/cubit/seller_profile_cubit.dart';
import '../../seller/features/profile/data/seller_identity_cache.dart';
import '../../seller/features/reviews/cubit/reviews_cubit.dart';
import '../../seller/services/new_orders_listener.dart';
import '../../shared/repositories/seller_order_repository.dart';
import '../../shared/repositories/banner_repository.dart';
import '../../shared/repositories/cart_repository.dart';
import '../../shared/repositories/favorites_repository.dart';
import '../../shared/repositories/seller_dashboard_repository.dart';
import '../../shared/repositories/seller_reviews_repository.dart';
import '../../shared/repositories/supabase_category_repository.dart';
import '../../shared/repositories/supabase_product_data_source.dart';
import '../connectivity/network_cubit.dart';
import '../storage/hive_boxes.dart';

/// Customer mode-scope: blocs and services torn down on a switch to seller.
void registerCustomerScope(GetIt sl) {
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
  sl.registerLazySingleton<CartBloc>(
    () => CartBloc(
      sl<CartRepository>(),
      analytics: sl<AnalyticsService>(),
    )..add(const LoadCart()),
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
  // NotificationsCubit is root-scoped (see registerCatalogModule) so seller
  // mode shares the same instance — no notification wiring belongs here.
}

/// Seller mode-scope: blocs and services torn down on a switch to customer.
void registerSellerScope(GetIt sl) {
  // Root-scoped orders bloc so the bottom-nav badge stays alive regardless of
  // which tab is active. Fires SellerOrdersRequested on creation; disposed
  // automatically when the seller scope is popped on mode switch.
  sl.registerLazySingleton<SellerOrdersBloc>(
    () => SellerOrdersBloc(sl<SellerOrderRepository>())
      ..add(const SellerOrdersRequested()),
    dispose: (bloc) => bloc.close(),
  );
  sl.registerLazySingleton<NewOrdersListener>(
    () => NewOrdersListener(
      sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
    ),
    dispose: (svc) => svc.dispose(),
  );
  // Hive-backed cache for the shop/seller/plan fields shown across the
  // dashboard greeting + profile header. Lives in the shared `cache` box,
  // which `performLogout` wipes — so the cache can never bleed across users.
  sl.registerLazySingleton<SellerIdentityCache>(
    () => SellerIdentityCache(sl<Box>(instanceName: HiveBoxes.cache)),
  );
  sl.registerFactory<SellerDashboardCubit>(
    () => SellerDashboardCubit(
      sl<SellerDashboardRepository>(),
      cache: sl<SellerIdentityCache>(),
      supabase: sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
    ),
  );
  sl.registerFactory<SellerProfileCubit>(
    () => SellerProfileCubit(
      sl<SupabaseClient>(),
      sl<SellerIdentityCache>(),
    ),
  );
  if (sl.isRegistered<SellerReviewsRepository>()) {
    sl.registerFactory<ReviewsCubit>(
      () => ReviewsCubit(sl<SellerReviewsRepository>()),
    );
  }
}
