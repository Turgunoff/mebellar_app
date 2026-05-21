import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../seller/features/products/data/add_product_repository.dart';
import '../../seller/features/products/data/attributes_repository.dart';
import '../../shared/repositories/seller_analytics_repository.dart';
import '../../shared/repositories/seller_dashboard_repository.dart';
import '../../shared/repositories/seller_onboarding_repository.dart';
import '../../shared/repositories/seller_order_repository.dart';
import '../../shared/repositories/seller_product_repository.dart';
import '../../shared/repositories/seller_reviews_repository.dart';
import '../../shared/repositories/seller_services_repository.dart';
import '../../shared/repositories/seller_verification_repository.dart';
import '../../shared/repositories/shop_settings_repository.dart';
import '../../shared/repositories/supabase_seller_analytics_repository.dart';
import '../../shared/repositories/supabase_seller_dashboard_repository.dart';
import '../../shared/repositories/supabase_seller_onboarding_repository.dart';
import '../../shared/repositories/supabase_seller_order_repository.dart';
import '../../shared/repositories/supabase_seller_product_repository.dart';
import '../../shared/repositories/supabase_seller_reviews_repository.dart';
import '../../shared/repositories/supabase_seller_services_repository.dart';
import '../../shared/repositories/supabase_seller_verification_repository.dart';
import '../../shared/repositories/supabase_shop_settings_repository.dart';
import '../../shared/repositories/supabase_tariff_repository.dart';
import '../../shared/repositories/tariff_repository.dart';
import '../realtime/realtime_service.dart';
import '../storage/hive_boxes.dart';
import 'repository_resolver.dart';

/// Root-scope seller-side repositories. Every seller repo is wired against
/// its Supabase implementation when a client is available; the legacy Dio/REST
/// `Remote*` variants remain as the no-Supabase fallback used by integration
/// tests that boot without a backing project.
void registerSellerModule(GetIt sl) {
  final resolver = RepositoryResolver.fromEnvironment(
    hasSupabase: sl.isRegistered<SupabaseClient>(),
  );
  final draftBox = sl<Box>(instanceName: HiveBoxes.onboardingDraft);

  sl.registerLazySingleton<SellerOnboardingRepository>(
    () => resolver.resolve<SellerOnboardingRepository>(
      supabase: () => SupabaseSellerOnboardingRepository(
        supabase: sl<SupabaseClient>(),
        draftBox: draftBox,
      ),
      remote: () => RemoteSellerOnboardingRepository(
        dio: sl<Dio>(),
        draftBox: draftBox,
        findRegionById: (id) => null,
      ),
    ),
  );

  sl.registerLazySingleton<SellerVerificationRepository>(
    () => resolver.resolve<SellerVerificationRepository>(
      supabase: () => SupabaseSellerVerificationRepository(
        supabase: sl<SupabaseClient>(),
      ),
      remote: () => RemoteSellerVerificationRepository(sl<Dio>()),
    ),
  );

  // Reviews — Supabase-only (no legacy Dio variant; the table is new).
  // Registered only when a Supabase client is available; integration tests
  // without one will not exercise the reviews surface.
  if (sl.isRegistered<SupabaseClient>()) {
    sl.registerLazySingleton<SellerReviewsRepository>(
      () => SupabaseSellerReviewsRepository(supabase: sl<SupabaseClient>()),
    );
  }

  sl.registerLazySingleton<SellerProductRepository>(
    () => resolver.resolve<SellerProductRepository>(
      supabase: () =>
          SupabaseSellerProductRepository(supabase: sl<SupabaseClient>()),
      remote: () => RemoteSellerProductRepository(sl<Dio>()),
    ),
  );

  // Add-product flow owns its own repository so the cubit stays free of the
  // broader (still read-only) SellerProductRepository surface. Requires
  // Supabase — skipped on offline/unit-test runs without a live project.
  if (sl.isRegistered<SupabaseClient>()) {
    sl.registerLazySingleton<AddProductRepository>(
      () => AddProductRepository(supabase: sl<SupabaseClient>()),
    );
    sl.registerLazySingleton<AttributesRepository>(
      () => SupabaseAttributesRepository(supabase: sl<SupabaseClient>()),
    );
  }

  // Dashboard reads live shop/product/order data so the empty-state
  // experience is exercised by default. Requires Supabase at root scope.
  sl.registerLazySingleton<SellerDashboardRepository>(
    () => SupabaseSellerDashboardRepository(sl<SupabaseClient>()),
  );

  // Analytics reads live data — the empty-revenue state is the source of
  // truth for sellers without orders yet.
  sl.registerLazySingleton<SellerAnalyticsRepository>(
    () => SupabaseSellerAnalyticsRepository(supabase: sl<SupabaseClient>()),
  );

  sl.registerLazySingleton<SellerOrderRepository>(
    () => resolver.resolve<SellerOrderRepository>(
      supabase: () => SupabaseSellerOrderRepository(
        supabase: sl<SupabaseClient>(),
        realtime: sl<RealtimeService>(),
      ),
      remote: () => RemoteSellerOrderRepository(sl<Dio>()),
    ),
    dispose: (repo) => repo.dispose(),
  );
  sl.registerLazySingleton<ShopSettingsRepository>(
    () => resolver.resolve<ShopSettingsRepository>(
      supabase: () =>
          SupabaseShopSettingsRepository(supabase: sl<SupabaseClient>()),
      remote: () => RemoteShopSettingsRepository(sl<Dio>()),
    ),
  );
  sl.registerLazySingleton<SellerServicesRepository>(
    () => resolver.resolve<SellerServicesRepository>(
      supabase: () =>
          SupabaseSellerServicesRepository(supabase: sl<SupabaseClient>()),
      remote: () => RemoteSellerServicesRepository(sl<Dio>()),
    ),
  );

  sl.registerLazySingleton<TariffRepository>(
    () => resolver.resolve<TariffRepository>(
      supabase: () =>
          SupabaseTariffRepository(supabase: sl<SupabaseClient>()),
      remote: () => RemoteTariffRepository(sl<Dio>()),
    ),
  );
}
