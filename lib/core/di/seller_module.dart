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
import '../../shared/repositories/supabase_seller_dashboard_repository.dart';
import '../../shared/repositories/supabase_seller_onboarding_repository.dart';
import '../../shared/repositories/supabase_seller_services_repository.dart';
import '../../shared/repositories/supabase_tariff_repository.dart';
import '../../shared/repositories/tariff_repository.dart';
import '../../shared/repositories/woody_seller_order_repository.dart';
import '../../shared/repositories/woody_seller_product_repository.dart';
import '../../shared/repositories/woody_seller_repositories.dart';
import '../../config/app_config.dart';
import '../auth/auth_repository.dart';
import '../network/woody_api_client.dart';
import '../storage/hive_boxes.dart';
import '../storage/r2_upload_client.dart';
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
  final useWoody = AppConfig.hasWoodyApi;

  sl.registerLazySingleton<SellerOnboardingRepository>(
    () => useWoody
        ? WoodySellerOnboardingRepository(
            api: sl<WoodyApiClient>(),
            draftBox: draftBox,
          )
        : resolver.resolve<SellerOnboardingRepository>(
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
    () => WoodySellerVerificationRepository(
      api: sl<WoodyApiClient>(),
      auth: sl<AuthRepository>(),
      uploads: sl<R2UploadClient>(),
    ),
  );

  // Reviews — Woody REST (`/seller/reviews`).
  sl.registerLazySingleton<SellerReviewsRepository>(
    () => WoodySellerReviewsRepository(api: sl<WoodyApiClient>()),
  );

  // Products — Woody REST (`/seller/products`).
  sl.registerLazySingleton<SellerProductRepository>(
    () => WoodySellerProductRepository(api: sl<WoodyApiClient>()),
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
  // experience is exercised by default. Prefer Woody REST when configured.
  sl.registerLazySingleton<SellerDashboardRepository>(
    () => useWoody
        ? WoodySellerDashboardRepository(api: sl<WoodyApiClient>())
        : SupabaseSellerDashboardRepository(sl<SupabaseClient>()),
  );

  // Analytics reads live data — the empty-revenue state is the source of
  // truth for sellers without orders yet.
  sl.registerLazySingleton<SellerAnalyticsRepository>(
    () => WoodySellerAnalyticsRepository(api: sl<WoodyApiClient>()),
  );

  // Orders — Woody REST (`/seller/orders`).
  sl.registerLazySingleton<SellerOrderRepository>(
    () => WoodySellerOrderRepository(api: sl<WoodyApiClient>()),
    dispose: (repo) => repo.dispose(),
  );
  sl.registerLazySingleton<ShopSettingsRepository>(
    () => WoodyShopSettingsRepository(
      api: sl<WoodyApiClient>(),
      uploads: sl<R2UploadClient>(),
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
      supabase: () => SupabaseTariffRepository(supabase: sl<SupabaseClient>()),
      remote: () => RemoteTariffRepository(sl<Dio>()),
    ),
  );
}
