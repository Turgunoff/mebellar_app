import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../customer/features/cart/bloc/cart_bloc.dart';
import '../../customer/features/categories/bloc/categories_bloc.dart';
import '../../customer/features/favorites/bloc/favorites_bloc.dart';
import '../../customer/features/home/bloc/home_bloc.dart';
import '../../customer/features/orders/cubit/profile_orders_cubit.dart';
import '../../customer/features/profile/cubit/profile_cubit.dart';
import '../../customer/services/order_tracking_service.dart';
import '../../seller/features/dashboard/bloc/seller_dashboard_cubit.dart';
import '../../seller/services/new_orders_listener.dart';
import '../../shared/repositories/banner_repository.dart';
import '../../shared/repositories/cart_repository.dart';
import '../../shared/repositories/favorites_repository.dart';
import '../../shared/repositories/seller_dashboard_repository.dart';
import '../../shared/repositories/supabase_category_repository.dart';
import '../../shared/repositories/supabase_product_data_source.dart';
import '../connectivity/network_cubit.dart';

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
  // NotificationsCubit is root-scoped (see registerCatalogModule) so seller
  // mode shares the same instance — no notification wiring belongs here.
}

/// Seller mode-scope: blocs and services torn down on a switch to customer.
void registerSellerScope(GetIt sl) {
  sl.registerLazySingleton<NewOrdersListener>(
    () => NewOrdersListener(
      sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
    ),
    dispose: (svc) => svc.dispose(),
  );
  sl.registerFactory<SellerDashboardCubit>(
    () => SellerDashboardCubit(sl<SellerDashboardRepository>()),
  );
}
