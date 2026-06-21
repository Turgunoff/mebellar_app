import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../analytics/analytics_service.dart';
import '../auth/auth_repository.dart';
import '../realtime/woody_realtime_service.dart';
import '../services/facebook_analytics_service.dart';
import '../../customer/features/cart/bloc/cart_bloc.dart';
import '../../customer/features/categories/bloc/categories_bloc.dart';
import '../../customer/features/favorites/bloc/favorites_bloc.dart';
import '../../customer/features/home/bloc/home_bloc.dart';
import '../../customer/features/orders/cubit/profile_orders_cubit.dart';
import '../../customer/features/payment/cubit/payment_cards_cubit.dart';
import '../../customer/features/profile/cubit/profile_cubit.dart';
import '../../customer/services/order_tracking_service.dart';
import '../../seller/features/dashboard/bloc/seller_dashboard_cubit.dart';
import '../../seller/features/orders/bloc/seller_orders_bloc.dart';
import '../../seller/features/profile/cubit/seller_profile_cubit.dart';
import '../../seller/features/profile/data/seller_identity_cache.dart';
import '../../seller/features/reviews/cubit/reviews_cubit.dart';
import '../../seller/services/new_orders_listener.dart';
import '../../shared/repositories/payment_cards_repository.dart';
import '../../shared/repositories/seller_order_repository.dart';
import '../../shared/repositories/seller_profile_repository.dart';
import '../../shared/repositories/profile_orders_repository.dart';
import '../../shared/repositories/banner_repository.dart';
import '../../shared/repositories/cart_repository.dart';
import '../../shared/repositories/favorites_repository.dart';
import '../../shared/repositories/hybrid_favorites_repository.dart';
import '../../shared/repositories/seller_dashboard_repository.dart';
import '../../shared/repositories/seller_reviews_repository.dart';
import '../../shared/repositories/category_data_source.dart';
import '../../shared/repositories/product_data_source.dart';
import '../connectivity/network_cubit.dart';
import '../i18n/app_locale_controller.dart';
import '../network/token_store.dart';
import '../storage/hive_boxes.dart';

/// Customer mode-scope: blocs and services torn down on a switch to seller.
void registerCustomerScope(GetIt sl) {
  sl.registerLazySingleton<HomeBloc>(
    () => HomeBloc(
      bannerRepo: sl<BannerRepository>(),
      productSource: sl<ProductDataSource>(),
      networkCubit: sl<NetworkCubit>(),
      localeController: sl<AppLocaleController>(),
    )..add(const HomeRequested()),
    dispose: (bloc) => bloc.close(),
  );
  sl.registerLazySingleton<OrderTrackingService>(
    () => OrderTrackingService(
      sl.isRegistered<WoodyRealtimeService>()
          ? sl<WoodyRealtimeService>()
          : null,
    ),
    dispose: (svc) => svc.dispose(),
  );
  sl.registerLazySingleton<CartBloc>(
    () => CartBloc(
      sl<CartRepository>(),
      analytics: sl<AnalyticsService>(),
      facebookAnalytics: sl.isRegistered<FacebookAnalyticsService>()
          ? sl<FacebookAnalyticsService>()
          : null,
      localeController: sl<AppLocaleController>(),
    )..add(const LoadCart()),
    dispose: (bloc) => bloc.close(),
  );
  sl.registerLazySingleton<FavoritesBloc>(() {
    final repo = sl<FavoritesRepository>();
    return FavoritesBloc(
      repo,
      localeController: sl<AppLocaleController>(),
      // The hybrid repo merges the guest list into the account on login, then
      // emits `sessionChanges` — reload products off THAT (not the raw token
      // stream) so the refetch lands after the merge, never racing it. Logout
      // empties the tab. Falls back to the token stream for a non-hybrid repo
      // (e.g. a test mock).
      authChanges: repo is HybridFavoritesRepository
          ? repo.sessionChanges
          : sl<TokenStore>().changes.map((pair) => pair != null),
    )..add(const FavoritesRequested());
  }, dispose: (bloc) => bloc.close());
  sl.registerLazySingleton<CategoriesBloc>(
    () => CategoriesBloc(
      sl<CategoryDataSource>(),
      networkCubit: sl<NetworkCubit>(),
      localeController: sl<AppLocaleController>(),
    )..add(const CategoriesRequested()),
    dispose: (bloc) => bloc.close(),
  );
  sl.registerLazySingleton<ProfileOrdersCubit>(
    () =>
        ProfileOrdersCubit(sl<ProfileOrdersRepository>(), sl<AuthRepository>()),
    dispose: (c) => c.close(),
  );
  sl.registerLazySingleton<ProfileCubit>(
    () => ProfileCubit(sl<AuthRepository>()),
    dispose: (c) => c.close(),
  );
  // Saved-cards list (profile → "My cards", and the checkout card picker).
  sl.registerLazySingleton<PaymentCardsCubit>(
    () => PaymentCardsCubit(sl<PaymentCardsRepository>()),
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
    () =>
        SellerOrdersBloc(sl<SellerOrderRepository>())
          ..add(const SellerOrdersRequested()),
    dispose: (bloc) => bloc.close(),
  );
  sl.registerLazySingleton<NewOrdersListener>(
    () => NewOrdersListener(
      sl.isRegistered<WoodyRealtimeService>()
          ? sl<WoodyRealtimeService>()
          : null,
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
      auth: sl<AuthRepository>(),
    ),
  );
  sl.registerFactory<SellerProfileCubit>(
    () => SellerProfileCubit(
      sl<SellerProfileRepository>(),
      sl<AuthRepository>(),
      sl<SellerIdentityCache>(),
    ),
  );
  if (sl.isRegistered<SellerReviewsRepository>()) {
    sl.registerFactory<ReviewsCubit>(
      () => ReviewsCubit(sl<SellerReviewsRepository>()),
    );
  }
}
