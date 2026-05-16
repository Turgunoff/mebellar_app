import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import '../../shared/repositories/supabase_seller_product_repository.dart';
import '../../shared/repositories/tariff_repository.dart';
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
      mock: () => MockSellerOnboardingRepository(
        draftBox: draftBox,
        findRegionById: MockRegions.findById,
      ),
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
        mock: MockSellerVerificationRepository.new,
        remote: () => RemoteSellerVerificationRepository(sl<Dio>()),
      ),
    );
  });

  sl.registerLazySingleton<SellerProductRepository>(
    () => resolver.resolve<SellerProductRepository>(
      supabase: () =>
          SupabaseSellerProductRepository(supabase: sl<SupabaseClient>()),
      mock: MockSellerProductRepository.new,
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
        mock: MockSellerOrderRepository.new,
        remote: () => RemoteSellerOrderRepository(sl<Dio>()),
      ),
    );
    sl.registerLazySingleton<ShopSettingsRepository>(
      () => resolver.resolve<ShopSettingsRepository>(
        mock: MockShopSettingsRepository.new,
        remote: () => RemoteShopSettingsRepository(sl<Dio>()),
      ),
    );
    sl.registerLazySingleton<SellerServicesRepository>(
      () => resolver.resolve<SellerServicesRepository>(
        mock: MockSellerServicesRepository.new,
        remote: () => RemoteSellerServicesRepository(sl<Dio>()),
      ),
    );
  });

  // Upgrade/payment flow is mock-backed, but MockTariffRepository reads the
  // live plan catalog from Supabase so the tariff cards stay server-driven.
  sl.registerLazySingleton<TariffRepository>(
    () => resolver.resolve<TariffRepository>(
      mock: () => MockTariffRepository(
        supabase:
            sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
      ),
      remote: () => RemoteTariffRepository(sl<Dio>()),
    ),
  );
}
