import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../seller/features/products/data/add_product_repository.dart';
import '../../seller/features/products/data/ar_scan_repository.dart';
import '../../seller/features/products/data/ar_token_repository.dart';
import '../../seller/features/products/data/attributes_repository.dart';
import '../../seller/features/products/data/exchange_rate_service.dart';
import '../../seller/features/sets/data/seller_set_repository.dart';
import '../../shared/repositories/seller_analytics_repository.dart';
import '../../shared/repositories/seller_dashboard_repository.dart';
import '../../shared/repositories/seller_onboarding_repository.dart';
import '../../shared/repositories/seller_order_repository.dart';
import '../../shared/repositories/seller_product_repository.dart';
import '../../shared/repositories/seller_profile_repository.dart';
import '../../shared/repositories/seller_reviews_repository.dart';
import '../../shared/repositories/seller_services_repository.dart';
import '../../shared/repositories/seller_verification_repository.dart';
import '../../shared/repositories/seller_wallet_repository.dart';
import '../../shared/repositories/shop_settings_repository.dart';
import '../../shared/repositories/tariff_repository.dart';
import '../../shared/repositories/woody_seller_order_repository.dart';
import '../../shared/repositories/woody_seller_product_repository.dart';
import '../../shared/repositories/woody_seller_repositories.dart';
import '../../shared/repositories/woody_seller_services_repository.dart';
import '../../shared/repositories/woody_seller_wallet_repository.dart';
import '../../shared/repositories/woody_tariff_repository.dart';
import '../auth/auth_repository.dart';
import '../network/woody_api_client.dart';
import '../storage/hive_boxes.dart';
import '../storage/r2_upload_client.dart';

/// Root-scope seller-side repositories. Every seller surface is wired to its
/// Woody REST implementation (`/seller/*`).
void registerSellerModule(GetIt sl) {
  final draftBox = sl<Box>(instanceName: HiveBoxes.onboardingDraft);

  sl.registerLazySingleton<SellerOnboardingRepository>(
    () => WoodySellerOnboardingRepository(
      api: sl<WoodyApiClient>(),
      draftBox: draftBox,
      uploads: sl<R2UploadClient>(),
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

  // Furniture sets (garnitur) — Woody REST (`/seller/sets`). Concrete repo
  // (no abstract interface / mock pair) over the shared API client.
  sl.registerLazySingleton<WoodySellerSetRepository>(
    () => WoodySellerSetRepository(api: sl<WoodyApiClient>()),
  );

  // Add-product flow owns its own repository so the cubit stays free of the
  // broader (read-only) SellerProductRepository surface.
  sl.registerLazySingleton<AddProductRepository>(
    () => AddProductRepository(
      api: sl<WoodyApiClient>(),
      auth: sl<AuthRepository>(),
      uploads: sl<R2UploadClient>(),
    ),
  );

  // AR model request (Photos-to-3D) — the seller requests a model per part; an
  // admin reviews, picks the best photos, and sends them to Meshy. No upload
  // here — the admin chooses from the product's existing images.
  sl.registerLazySingleton<ArScanRepository>(
    () => WoodyArScanRepository(api: sl<WoodyApiClient>()),
  );
  // AR tokenisation: balance read + package purchase (Payme) for the metered
  // generation flow.
  sl.registerLazySingleton<ArTokenRepository>(
    () => WoodyArTokenRepository(api: sl<WoodyApiClient>()),
  );
  sl.registerLazySingleton<AttributesRepository>(
    () => WoodyAttributesRepository(api: sl<WoodyApiClient>()),
  );

  // CBU daily USD→UZS rate for the price field's currency toggle. External
  // public feed (not woody_backend) — the backend only ever receives UZS.
  sl.registerLazySingleton<ExchangeRateService>(() => CbuExchangeRateService());

  // Dashboard — Woody REST (`/seller/dashboard`).
  sl.registerLazySingleton<SellerDashboardRepository>(
    () => WoodySellerDashboardRepository(api: sl<WoodyApiClient>()),
  );

  // Profile header reads (/seller/me, /seller/shop, /seller/tariff/current).
  sl.registerLazySingleton<SellerProfileRepository>(
    () => WoodySellerProfileRepository(sl<WoodyApiClient>()),
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
    () => WoodySellerServicesRepository(api: sl<WoodyApiClient>()),
  );

  sl.registerLazySingleton<TariffRepository>(
    () => WoodyTariffRepository(
      api: sl<WoodyApiClient>(),
      auth: sl<AuthRepository>(),
      uploads: sl<R2UploadClient>(),
    ),
  );

  // Wallet — balance/debt state + automated Payme/Click top-ups (`/seller/wallet*`).
  sl.registerLazySingleton<SellerWalletRepository>(
    () => WoodySellerWalletRepository(api: sl<WoodyApiClient>()),
  );
}
