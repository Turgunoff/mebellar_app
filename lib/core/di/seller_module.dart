import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../seller/features/products/data/add_product_repository.dart';
import '../../shared/mock/mock_regions.dart';
import '../../shared/mock/mock_seller_onboarding_repository.dart';
import '../../shared/mock/mock_seller_order_repository.dart';
import '../../shared/mock/mock_seller_product_repository.dart';
import '../../shared/mock/mock_seller_services_repository.dart';
import '../../shared/mock/mock_seller_verification_repository.dart';
import '../../shared/mock/mock_shop_settings_repository.dart';
import '../../shared/mock/mock_tariff_repository.dart';
import '../../shared/repositories/seller_dashboard_repository.dart';
import '../../shared/repositories/seller_onboarding_repository.dart';
import '../../shared/repositories/seller_order_repository.dart';
import '../../shared/repositories/seller_product_repository.dart';
import '../../shared/repositories/seller_services_repository.dart';
import '../../shared/repositories/seller_verification_repository.dart';
import '../../shared/repositories/shop_settings_repository.dart';
import '../../shared/repositories/supabase_seller_dashboard_repository.dart';
import '../../shared/repositories/supabase_seller_onboarding_repository.dart';
import '../../shared/repositories/supabase_seller_order_repository.dart';
import '../../shared/repositories/supabase_seller_product_repository.dart';
import '../../shared/repositories/supabase_seller_services_repository.dart';
import '../../shared/repositories/supabase_seller_verification_repository.dart';
import '../../shared/repositories/supabase_shop_settings_repository.dart';
import '../../shared/repositories/supabase_tariff_repository.dart';
import '../../shared/repositories/tariff_repository.dart';
import '../realtime/realtime_service.dart';
import '../storage/hive_boxes.dart';
import 'repository_resolver.dart';

/// Root-scope seller-side repositories. The A.2 fulfillment repositories stay
/// unregistered until the feature flag flips — gated via
/// [RepositoryResolver.whenFulfillmentEnabled] so a production build never
/// wires fake data.
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
      mock: AppConfig.useMocks
          ? () => MockSellerOnboardingRepository(
                draftBox: draftBox,
                findRegionById: MockRegions.findById,
              )
          : null,
      remote: () => RemoteSellerOnboardingRepository(
        dio: sl<Dio>(),
        draftBox: draftBox,
        findRegionById: (id) => null,
      ),
    ),
  );

  // ROADMAP A.2 — seller KYC verification has no live backend yet; registered
  // only when the fulfillment flag is on so a release build can never surface
  // a fake verification state.
  resolver.whenFulfillmentEnabled(() {
    sl.registerLazySingleton<SellerVerificationRepository>(
      () => resolver.resolve<SellerVerificationRepository>(
        supabase: () => SupabaseSellerVerificationRepository(
          supabase: sl<SupabaseClient>(),
        ),
        mock: AppConfig.useMocks ? MockSellerVerificationRepository.new : null,
        remote: () => RemoteSellerVerificationRepository(sl<Dio>()),
      ),
    );
  });

  sl.registerLazySingleton<SellerProductRepository>(
    () => resolver.resolve<SellerProductRepository>(
      supabase: () =>
          SupabaseSellerProductRepository(supabase: sl<SupabaseClient>()),
      mock: AppConfig.useMocks ? MockSellerProductRepository.new : null,
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
  }

  // Dashboard is intentionally NOT mocked — every build reads live
  // shop/product/order data so the empty-state experience is exercised by
  // default. Requires Supabase to be registered at root scope.
  sl.registerLazySingleton<SellerDashboardRepository>(
    () => SupabaseSellerDashboardRepository(sl<SupabaseClient>()),
  );

  // ROADMAP A.2 / B.1 — orders / shop-settings / seller-services stay gated
  // behind the fulfillment flag until their Supabase repositories ship.
  resolver.whenFulfillmentEnabled(() {
    sl.registerLazySingleton<SellerOrderRepository>(
      () => resolver.resolve<SellerOrderRepository>(
        supabase: () => SupabaseSellerOrderRepository(
          supabase: sl<SupabaseClient>(),
          realtime: sl<RealtimeService>(),
        ),
        mock: AppConfig.useMocks ? MockSellerOrderRepository.new : null,
        remote: () => RemoteSellerOrderRepository(sl<Dio>()),
      ),
      dispose: (repo) => repo.dispose(),
    );
    sl.registerLazySingleton<ShopSettingsRepository>(
      () => resolver.resolve<ShopSettingsRepository>(
        supabase: () =>
            SupabaseShopSettingsRepository(supabase: sl<SupabaseClient>()),
        mock: AppConfig.useMocks ? MockShopSettingsRepository.new : null,
        remote: () => RemoteShopSettingsRepository(sl<Dio>()),
      ),
    );
    sl.registerLazySingleton<SellerServicesRepository>(
      () => resolver.resolve<SellerServicesRepository>(
        supabase: () =>
            SupabaseSellerServicesRepository(supabase: sl<SupabaseClient>()),
        mock: AppConfig.useMocks ? MockSellerServicesRepository.new : null,
        remote: () => RemoteSellerServicesRepository(sl<Dio>()),
      ),
    );
  });

  // ROADMAP B.1 — the live Supabase tariff write path (P2P receipt upload +
  // upgrade request). The mock stays as the offline/no-Supabase fallback and
  // still reads the live plan catalog when a client is available.
  sl.registerLazySingleton<TariffRepository>(
    () => resolver.resolve<TariffRepository>(
      supabase: () =>
          SupabaseTariffRepository(supabase: sl<SupabaseClient>()),
      mock: AppConfig.useMocks
          ? () => MockTariffRepository(
                supabase: sl.isRegistered<SupabaseClient>()
                    ? sl<SupabaseClient>()
                    : null,
              )
          : null,
      remote: () => RemoteTariffRepository(sl<Dio>()),
    ),
  );
}
