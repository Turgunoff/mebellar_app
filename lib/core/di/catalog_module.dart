import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/app_config.dart';
import '../../customer/features/notifications/cubit/notifications_cubit.dart';
import '../../customer/widgets/view_mode_toggle.dart';
import '../analytics/analytics_service.dart';
import '../analytics/firebase_analytics_service.dart';
import '../analytics/noop_analytics_service.dart';
import '../services/facebook_analytics_service.dart';
import '../../shared/repositories/banner_repository.dart';
import '../../shared/repositories/cached_banner_repository.dart';
import '../../shared/repositories/cached_category_repository.dart';
import '../../shared/repositories/cached_product_data_source.dart';
import '../../shared/repositories/cart_repository.dart';
import '../../shared/repositories/chat_repository.dart';
import '../../shared/repositories/checkout_repository.dart';
import '../../shared/repositories/customer_reviews_repository.dart';
import '../../shared/repositories/favorites_repository.dart';
import '../../shared/repositories/hive_cart_repository.dart';
import '../../shared/repositories/hive_favorites_repository.dart';
import '../../shared/repositories/hybrid_cart_repository.dart';
import '../../shared/repositories/hybrid_favorites_repository.dart';
import '../../shared/repositories/news_repository.dart';
import '../../shared/repositories/notifications_repository.dart';
import '../../shared/repositories/order_repository.dart';
import '../../shared/repositories/payment_repository.dart';
import '../../shared/repositories/profile_orders_repository.dart';
import '../../shared/repositories/category_data_source.dart';
import '../../shared/repositories/notifications_data_source.dart';
import '../../shared/repositories/product_data_source.dart';
import '../../shared/repositories/shop_repository.dart';
import '../../shared/repositories/woody_banner_repository.dart';
import '../../shared/repositories/woody_category_repository.dart';
import '../../shared/repositories/woody_chat_repositories.dart';
import '../../shared/repositories/woody_customer_repositories.dart';
import '../../shared/repositories/woody_product_repository.dart';
import '../../shared/repositories/woody_set_repository.dart';
import '../../shared/repositories/woody_shop_repository.dart';
import '../../customer/features/ai_designer/cubit/ai_designer_cubit.dart';
import '../../customer/features/ai_designer/data/ai_designer_repository.dart';
import '../../customer/features/support/repository/support_chat_repository.dart';
import '../../customer/features/support/repository/woody_support_chat_repository.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_repository.dart';
import '../network/token_store.dart';
import '../network/woody_api_client.dart';
import '../realtime/woody_realtime_service.dart';
import '../storage/app_settings.dart';
import '../storage/cache_store.dart';
import '../storage/hive_boxes.dart';
import '../storage/r2_upload_client.dart';

/// Root-scope catalog + customer-shared repositories and data sources.
///
/// Every read goes against the woody_backend REST surface (`api.woody.uz`)
/// via `WoodyApiClient`. There is no other backend.
void registerCatalogModule(GetIt sl) {
  final useWoody = AppConfig.hasWoodyApi;

  // Single source of truth for the grid/list view-mode toggle, shared live by
  // the home feed and every category list so a toggle on one surface applies
  // everywhere (including a tab kept alive in the shell). Backed by AppSettings
  // for cross-restart persistence.
  sl.registerLazySingleton<ProductViewModeController>(
    () => ProductViewModeController(sl<AppSettings>()),
  );

  CategoryDataSource buildCategoryDs() =>
      WoodyCategoryRepository(api: sl<WoodyApiClient>());

  ProductDataSource buildProductDs() =>
      WoodyProductRepository(api: sl<WoodyApiClient>());

  // --- data sources (Woody REST — no offline fallback) ---------------------
  // The customer-facing catalog data sources are Woody-only: production never
  // boots without the Woody API base URL (see `AppConfig.assertConfigured`),
  // so a fallback would only mask a misconfigured build.
  if (useWoody) {
    // Categories + recommended products + banners are wrapped in cache-aside
    // decorators so the home shell hydrates from Hive at 0 ms on every cold
    // start (see CachedCategoryRepository / CachedProductDataSource /
    // CachedBannerRepository for TTLs and the rationale per call). The
    // underlying Woody repos still run — the decorator just
    // adds a write-through layer + a synchronous peek() entry point.
    sl.registerLazySingleton<CategoryDataSource>(
      () => CachedCategoryRepository(
        inner: buildCategoryDs(),
        cache: sl<CacheStore>(),
      ),
    );
    sl.registerLazySingleton<ProductDataSource>(
      () => CachedProductDataSource(
        inner: buildProductDs(),
        cache: sl<CacheStore>(),
      ),
    );

    // Order-scoped chats — Woody REST + realtime fan-out. The WS service
    // drives live message inserts and chat-list refreshes; null-safe so
    // no-backend builds degrade to on-demand snapshots.
    sl.registerLazySingleton<ChatRepository>(
      () => WoodyChatRepository(
        api: sl<WoodyApiClient>(),
        realtime: sl.isRegistered<WoodyRealtimeService>()
            ? sl<WoodyRealtimeService>()
            : null,
        uploads: sl.isRegistered<R2UploadClient>()
            ? sl<R2UploadClient>()
            : null,
      ),
    );
    // Customer support chat — single per-user thread over Woody REST +
    // realtime (`/support/*`). WS drives admin replies + read receipts; the
    // upload client (null-safe) handles image/audio attachments.
    sl.registerLazySingleton<SupportChatRepository>(
      () => WoodySupportChatRepository(
        api: sl<WoodyApiClient>(),
        realtime: sl.isRegistered<WoodyRealtimeService>()
            ? sl<WoodyRealtimeService>()
            : null,
        uploads: sl.isRegistered<R2UploadClient>()
            ? sl<R2UploadClient>()
            : null,
      ),
    );

    // Notifications inbox data source — Woody REST (`/notifications`).
    sl.registerLazySingleton<NotificationDataSource>(
      () => WoodyNotificationDataSource(api: sl<WoodyApiClient>()),
    );

    // Customer-side product reviews — Woody REST.
    sl.registerLazySingleton<CustomerReviewsRepository>(
      () => WoodyCustomerReviewsRepository(api: sl<WoodyApiClient>()),
    );

    // Public shop/seller profile (`/catalog/shops/{id}` + its product list).
    sl.registerLazySingleton<ShopRepository>(
      () => WoodyShopRepository(api: sl<WoodyApiClient>()),
    );

    // Furniture sets (garnitur) — public `/catalog/sets*`. Drives the buyer
    // "view the whole set in your room" AR / 2D experience.
    sl.registerLazySingleton<WoodySetRepository>(
      () => WoodySetRepository(api: sl<WoodyApiClient>()),
    );

    // NewsDataSource — public broadcast feed; only when the Woody API is live.
    sl.registerLazySingleton<NewsDataSource>(
      () => WoodyNewsRepository(
        api: sl<WoodyApiClient>(),
        readsBox: sl<Box>(instanceName: HiveBoxes.newsReads),
      ),
    );
  }

  // Analytics — Firebase-backed when the SDK initialised cleanly at boot,
  // a no-op otherwise so call sites never need to null-check. Lives in the
  // root scope: events from customer/seller modes both fan into one sink.
  sl.registerLazySingleton<AnalyticsService>(() {
    try {
      return FirebaseAnalyticsService();
    } catch (_) {
      return const NoopAnalyticsService();
    }
  });

  // Facebook App Events — a SEPARATE conversion sink (installs + standard
  // events + custom AR / AI signals) for ad-campaign attribution. One lazy
  // singleton in the root scope, shared by customer + seller call sites. Its
  // methods are non-throwing, so call sites never need to null-check.
  sl.registerLazySingleton<FacebookAnalyticsService>(
    FacebookAnalyticsService.new,
  );

  // NotificationsCubit lives in the ROOT scope so a single instance feeds
  // both the customer inbox + bell badge AND the seller inbox + bell badge,
  // and the realtime subscription survives mode switches.
  sl.registerLazySingleton<NotificationsCubit>(
    () => NotificationsCubit(
      sl<NotificationDataSource>(),
      realtime: sl.isRegistered<WoodyRealtimeService>()
          ? sl<WoodyRealtimeService>()
          : null,
      auth: sl.isRegistered<AuthRepository>() ? sl<AuthRepository>() : null,
      newsRepo: sl.isRegistered<NewsDataSource>() ? sl<NewsDataSource>() : null,
    )..load(),
    dispose: (c) => c.close(),
  );

  // --- catalog repositories (Woody REST) -----------------------------------
  sl.registerLazySingleton<BannerRepository>(
    () => CachedBannerRepository(
      inner: WoodyBannerRepository(api: sl<WoodyApiClient>()),
      cache: sl<CacheStore>(),
    ),
  );
  // Hybrid cart: a Hive-backed local cart for guests, the backend cart once
  // signed in, and a merge of the former into the latter on login. The active
  // side is chosen per-call from the live token state.
  sl.registerLazySingleton<CartRepository>(() {
    final tokens = sl<TokenStore>();
    return HybridCartRepository(
      remote: WoodyCartRepository(api: sl<WoodyApiClient>()),
      local: HiveCartRepository(box: sl<Box>(instanceName: HiveBoxes.cart)),
      isSignedIn: () => tokens.current != null,
      authChanges: tokens.changes.map((pair) => pair != null),
    );
  }, dispose: (r) => (r as HybridCartRepository).dispose());
  // Hybrid favorites: mirrors the cart — a Hive-backed local list for guests,
  // the backend account once signed in, and a union-merge of the former into
  // the latter on login.
  sl.registerLazySingleton<FavoritesRepository>(() {
    final tokens = sl<TokenStore>();
    return HybridFavoritesRepository(
      remote: WoodyFavoritesRepository(api: sl<WoodyApiClient>()),
      local: HiveFavoritesRepository(
        box: sl<Box>(instanceName: HiveBoxes.favorites),
      ),
      isSignedIn: () => tokens.current != null,
      authChanges: tokens.changes.map((pair) => pair != null),
    );
  }, dispose: (r) => (r as HybridFavoritesRepository).dispose());
  sl.registerLazySingleton<OrderRepository>(
    () => WoodyOrderRepository(sl<WoodyApiClient>()),
  );
  sl.registerLazySingleton<ProfileOrdersRepository>(
    () => WoodyProfileOrdersRepository(sl<WoodyApiClient>()),
  );
  sl.registerLazySingleton<CheckoutRepository>(
    () => WoodyCheckoutRepository(sl<WoodyApiClient>()),
  );
  // Checkout deep-links: mints a Payme/Click checkout URL for an order
  // (backend `/orders/{id}/pay/{provider}`), opened in the payment app.
  sl.registerLazySingleton<PaymentRepository>(
    () => WoodyPaymentRepository(api: sl<WoodyApiClient>()),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => WoodyNotificationsRepository(api: sl<WoodyApiClient>()),
  );

  // AI interior-designer chat (`POST /ai/chat`). Always registered — it
  // degrades gracefully (returns an unavailable reply) if the backend has the
  // feature off, so no `useWoody` guard is needed.
  sl.registerLazySingleton<AiDesignerRepository>(
    () => WoodyAiDesignerRepository(sl<WoodyApiClient>()),
  );
  // The chat cubit is a ROOT-scope SINGLETON (provided to the screen via
  // BlocProvider.value), NOT built per-route — so popping the chat screen does
  // not close it: an in-flight AI request keeps running in the background and
  // persists its reply to Hive (background-execution resilience).
  sl.registerLazySingleton<AiDesignerCubit>(
    () => AiDesignerCubit(
      repository: sl<AiDesignerRepository>(),
      // Drives the per-user history restore-on-login / clear-on-logout. Auth is
      // registered in auth_module (before this module), so it's always ready.
      authCubit: sl<AuthCubit>(),
      analytics: sl<AnalyticsService>(),
      facebookAnalytics: sl.isRegistered<FacebookAnalyticsService>()
          ? sl<FacebookAnalyticsService>()
          : null,
      // Uploads the room photo to R2 so it persists past the session; absent →
      // the chat degrades to a text-only (non-persisted) image turn.
      uploads: sl.isRegistered<R2UploadClient>() ? sl<R2UploadClient>() : null,
    ),
    dispose: (cubit) => cubit.close(),
  );
}
