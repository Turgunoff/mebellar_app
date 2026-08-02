// Landing-page screenshot generator.
//
// Drives the real app UI on a device/simulator and captures the three frames
// the `woody_frontend` interactive phone showcase needs:
//
//   buyer-home      — customer home: banners, categories, product grid
//   product-detail  — catalog product page (gallery, price, logistics)
//   seller-dash     — seller dashboard: revenue hero, KPIs, leaderboard
//
// The production catalog is empty pre-launch, so the run boots the real DI
// graph and then shadows the catalog data sources inside a `screenshot` GetIt
// scope with curated showcase content (see `showcase_data.dart`). Everything
// else — theme, fonts, layout, widgets — is the real production UI.
//
// Run (simulator/device id from `flutter devices`):
//
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshot_generator_test.dart \
//     --dart-define-from-file=env/prod.json \
//     --dart-define=SCREENSHOT_MODE=true \
//     -d <device-id>
//
// PNGs land in `screenshots/` (written by the driver's onScreenshot) AND in
// the app sandbox `Documents/screenshots/` (belt-and-braces fallback, pull
// with `xcrun simctl get_app_container <udid> com.mebellar.app data`).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:woody_app/config/app_config.dart';
import 'package:woody_app/config/app_mode.dart';
import 'package:woody_app/core/auth/app_mode_cubit.dart';
import 'package:woody_app/core/auth/auth_cubit.dart';
import 'package:woody_app/core/cache/app_cache_cubit.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/storage/app_settings.dart';
import 'package:woody_app/core/storage/hive_boxes.dart';
import 'package:woody_app/core/theme/seller_theme.dart';
import 'package:woody_app/core/theme/theme_cubit.dart';
import 'package:woody_app/customer/customer_app.dart';
import 'package:woody_app/customer/features/home/bloc/home_bloc.dart';
import 'package:woody_app/customer/features/home/widgets/premium/premium_product_card.dart';
import 'package:woody_app/customer/features/product_list/screens/catalog_product_detail_screen.dart';
import 'package:woody_app/firebase_options.dart';
import 'package:woody_app/main.dart' show AppLocaleScope;
import 'package:woody_app/seller/features/dashboard/bloc/seller_dashboard_cubit.dart';
import 'package:woody_app/seller/features/dashboard/dashboard_screen.dart';
import 'package:woody_app/seller/widgets/seller_bottom_nav.dart';
import 'package:woody_app/shared/repositories/banner_repository.dart';
import 'package:woody_app/shared/repositories/customer_reviews_repository.dart';
import 'package:woody_app/shared/repositories/product_data_source.dart';
import 'package:woody_app/shared/repositories/seller_dashboard_repository.dart';
import 'package:woody_app/shared/repositories/cart_repository.dart';
import 'package:woody_app/shared/repositories/hybrid_cart_repository.dart';
import 'package:woody_app/shared/repositories/hive_cart_repository.dart';
import 'package:woody_app/shared/repositories/favorites_repository.dart';
import 'package:woody_app/shared/repositories/hybrid_favorites_repository.dart';
import 'package:woody_app/shared/models/product.dart';
import 'package:woody_app/customer/features/product_list/screens/product_list_screen.dart';
import 'package:woody_app/customer/features/search/screens/search_screen.dart';
import 'package:woody_app/customer/features/cart/screens/cart_screen.dart';
import 'package:woody_app/customer/features/favorites/screens/favorites_screen.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'showcase_data.dart';

/// Pumps frames while real wall-clock time passes, so network images and
/// async blocs make progress. `pumpAndSettle` is unusable here — shimmer and
/// the banner autoplay never settle.
Future<void> settleFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 120);
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await Future<void>.delayed(step);
    await tester.pump();
    elapsed += step;
  }
}

/// Dual-path capture: the integration_test screenshot channel (delivered to
/// the driver's `onScreenshot`) plus a raw PNG dumped into the app sandbox,
/// recoverable via `simctl get_app_container` if the channel misbehaves.
Future<void> capture(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  try {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(
      Offset.zero & view.size,
      pixelRatio: view.flutterView.devicePixelRatio,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/screenshots/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      debugPrint('[screenshot] sandbox copy -> ${file.path}');
    }
  } catch (e) {
    debugPrint('[screenshot] sandbox dump failed for $name: $e');
  }
  await binding.takeScreenshot(name);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generate landing showcase screenshots', (tester) async {
    // Overflow stripes fail the integration binding even when the captured
    // frames are usable — swallow only RenderFlex overflow reports so the
    // drive still exits 0 and writes every PNG.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    // ── Boot the real DI graph (mirror of _bootstrapAndRun, minus push) ──
    AppConfig.assertConfigured();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
    }
    await initRootScope();
    await initModeScope(AppMode.customer);

    // Skip first-launch gates — router redirects on onboarding_seen (3D
    // carousel) and the legacy tutorial key still exists for old installs.
    await sl<AppSettings>().setOnboardingSeen(true);
    await sl<Box>(
      instanceName: HiveBoxes.settings,
    ).put('tutorial_seen_v1', true);

    // Skip the home ShowcaseView coach-marks (AR demo + AI FAB) — they cover
    // the feed and block product-card taps during capture.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_ar_demo', true);
    await prefs.setBool('has_seen_ai_showcase', true);

    final localeController = sl<AppLocaleController>();
    AppTranslations.setInstance(
      AppTranslations.forLocale(localeController.value),
    );

    // ── Shadow the catalog with showcase content ──
    sl.pushNewScope(scopeName: 'screenshot');
    sl.registerLazySingleton<ProductDataSource>(ShowcaseProductDataSource.new);
    sl.registerLazySingleton<BannerRepository>(ShowcaseBannerRepository.new);
    sl.registerLazySingleton<CustomerReviewsRepository>(
      ShowcaseReviewsRepository.new,
    );
    sl.registerLazySingleton<HomeBloc>(
      () => HomeBloc(
        bannerRepo: sl<BannerRepository>(),
        productSource: sl<ProductDataSource>(),
      )..add(const HomeRequested()),
      dispose: (b) => b.close(),
    );
    sl.registerLazySingleton<SellerDashboardRepository>(
      ShowcaseSellerDashboardRepository.new,
    );
    sl.registerFactory<SellerDashboardCubit>(
      () => SellerDashboardCubit(sl<SellerDashboardRepository>()),
    );

    // Seed the guest local stores so the cart + favourites screens read as
    // "in use" — both repos are hybrid; the local (Hive) side works offline
    // and is what a logged-out shopper hits.
    final cartLocal =
        (sl<CartRepository>() as HybridCartRepository).local
            as HiveCartRepository;
    await cartLocal.addProduct(showcaseProducts[0], quantity: 1);
    await cartLocal.addProduct(showcaseProducts[2], quantity: 2);
    await cartLocal.addProduct(showcaseProducts[3], quantity: 1);

    final favLocal =
        (sl<FavoritesRepository>() as HybridFavoritesRepository).local;
    await favLocal.toggle(Product.fromModel(showcaseProducts[1]));
    await favLocal.toggle(Product.fromModel(showcaseProducts[4]));
    await favLocal.toggle(Product.fromModel(showcaseProducts[5]));

    // ── 1+2. Customer surface ──
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
          BlocProvider<AppCacheCubit>.value(value: sl<AppCacheCubit>()),
          BlocProvider<AuthCubit>.value(value: sl<AuthCubit>()),
          BlocProvider<AppModeCubit>.value(value: sl<AppModeCubit>()),
        ],
        child: AppLocaleScope(
          controller: localeController,
          child: const CustomerApp(),
        ),
      ),
    );

    // Let the feed + banner/product images arrive and decode.
    await settleFor(tester, const Duration(seconds: 10));

    // Capture home at rest (fully expanded app bar) — a mid-scroll frame
    // clips the eyebrow under the scaled title.
    await capture(binding, tester, 'buyer-home');


    // Bring the product grid fully on-screen before tapping a card.
    expect(find.byType(PremiumProductCard), findsWidgets);
    final surface = tester.getCenter(find.byType(CustomerApp));
    await tester.dragFrom(surface, const Offset(0, -380));
    await settleFor(tester, const Duration(seconds: 2));

    // ── Product detail ──
    // Tap the first card whose center actually sits inside the viewport —
    // the masonry sliver keeps offscreen cards in the tree, and a tap on an
    // offscreen center silently no-ops.
    final screen = tester.getSize(find.byType(CustomerApp));
    var opened = false;
    final cardCount = find.byType(PremiumProductCard).evaluate().length;
    for (var i = 0; i < cardCount && !opened; i++) {
      final card = find.byType(PremiumProductCard).at(i);
      final center = tester.getCenter(card);
      if (center.dy < 120 || center.dy > screen.height - 140) continue;
      await tester.tap(card, warnIfMissed: false);
      await settleFor(tester, const Duration(seconds: 3));
      opened = find.byType(CatalogProductDetailScreen).evaluate().isNotEmpty;
    }
    if (!opened) {
      // Last resort: drive the router directly so the detail capture never
      // depends on hit-testing heuristics.
      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push(
        '/product-detail/${showcaseProducts.first.id}',
        extra: showcaseProducts.first,
      );
      await settleFor(tester, const Duration(seconds: 3));
    }
    expect(find.byType(CatalogProductDetailScreen), findsOneWidget);

    // Gallery + similar-products images.
    await settleFor(tester, const Duration(seconds: 6));
    await capture(binding, tester, 'product-detail');

    // ── Catalog / search / cart / favourites ──
    // The detail page sits below the GoRouter, so its element resolves the
    // live router; reuse it to drive the remaining customer surfaces by route
    // instead of relying on fragile hit-testing.
    final router = GoRouter.of(
      tester.element(find.byType(CatalogProductDetailScreen)),
    );
    router.pop(); // back to home
    await settleFor(tester, const Duration(seconds: 1));

    // Catalog: a category's product grid (showcase sofa category).
    router.push('/product-list?categoryId=show-cat-sofa&categoryName=Divanlar');
    await settleFor(tester, const Duration(seconds: 4));
    expect(find.byType(ProductListScreen), findsOneWidget);
    await capture(binding, tester, 'catalog');
    router.pop();
    await settleFor(tester, const Duration(seconds: 1));

    // Search: type a query and let the showcase results populate.
    router.push('/search');
    await settleFor(tester, const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField).first, 'divan');
    await settleFor(tester, const Duration(seconds: 3));
    expect(find.byType(SearchScreen), findsOneWidget);
    await capture(binding, tester, 'search');
    router.pop();
    await settleFor(tester, const Duration(seconds: 1));

    // Cart: pre-seeded with three showcase products at boot.
    router.push('/cart');
    await settleFor(tester, const Duration(seconds: 3));
    expect(find.byType(CartScreen), findsOneWidget);
    await capture(binding, tester, 'cart');
    router.pop();
    await settleFor(tester, const Duration(seconds: 1));

    // Favourites: pre-seeded with three showcase products at boot.
    router.push('/favorites');
    await settleFor(tester, const Duration(seconds: 3));
    expect(find.byType(FavoritesScreen), findsOneWidget);
    await capture(binding, tester, 'favorites');
    router.pop();
    await settleFor(tester, const Duration(seconds: 1));

    // ── 3. Seller dashboard (showcase repository, real widgets/theme) ──
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: sellerLightTheme,
        home: Scaffold(
          body: const SellerDashboardScreen(),
          bottomNavigationBar: SellerBottomNav(
            currentIndex: 0,
            onChanged: (_) {},
            items: [
              SellerNavItem(
                icon: Iconsax.element_3,
                label: tr('seller.tab_dashboard'),
              ),
              SellerNavItem(icon: Iconsax.box, label: tr('seller.tab_products')),
              SellerNavItem(
                icon: Iconsax.shopping_bag,
                label: tr('seller.tab_orders'),
              ),
              SellerNavItem(
                icon: Iconsax.chart_2,
                label: tr('seller.tab_analytics'),
              ),
              SellerNavItem(icon: Iconsax.user, label: tr('profile.title')),
            ],
          ),
        ),
      ),
    );

    await settleFor(tester, const Duration(seconds: 7));
    await capture(binding, tester, 'seller-dash');
  });
}
