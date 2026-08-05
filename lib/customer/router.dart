import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../config/app_mode.dart';
import '../core/deeplink/deferred_deep_link_service.dart';
import '../core/di/service_locator.dart';
import '../core/i18n/i18n.dart';
import '../shared/models/product_model.dart';
import '../shared/chat/screens/chat_thread_screen.dart';
import '../shared/chat/screens/chats_list_screen.dart';
import '../shared/models/chat.dart';
import '../shared/repositories/category_data_source.dart';
import '../shared/repositories/product_data_source.dart';
import '../core/logging/app_navigation_logger.dart';
import '../core/logging/app_logger.dart';
import '../shared/models/cart_item_model.dart';
import '../shared/widgets/brand_refresh_indicator.dart';
import '../shared/widgets/notification_simulator_screen.dart';
import 'customer_app.dart';
import 'features/ai_designer/cubit/ai_designer_cubit.dart';
import 'features/ai_designer/screens/ai_assistant_chat_screen.dart';
import 'features/broadcasts/screens/broadcast_placeholder_screen.dart';
import 'features/cart/screens/cart_screen.dart';
import 'features/categories/screens/categories_screen.dart';
import 'features/product_list/cubit/product_list_cubit.dart';
import 'features/product_list/screens/product_list_screen.dart';
import 'features/product_list/screens/catalog_product_detail_screen.dart';
import 'features/checkout/screens/checkout_screen.dart';
import 'features/favorites/screens/favorites_screen.dart';
import 'features/orders/screens/order_detail_screen.dart';
import 'features/orders/screens/orders_history_screen.dart';
import 'features/notifications/screens/notifications_screen.dart'
    as customer_notifications;
import 'features/search/screens/search_screen.dart';
import 'features/shop/screens/shop_profile_screen.dart';
import 'features/support/screens/support_chat_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart'
    as customer_onboarding;
import 'features/tutorial/tutorial_screen.dart';
import '../seller/features/onboarding/screens/onboarding_screen.dart';

/// Executes a customer-side deep link (notification tap, pending route).
/// Tab destinations — surfaces that live on the bottom nav, like `/profile`
/// — switch the home shell's tab via the `?tab=` query so the user lands on
/// the real tab with the nav bar visible, not a pushed standalone copy.
/// Everything else is pushed so Back returns to where the user was.
void navigateCustomerRoute(GoRouter router, String route) {
  const tabRoutes = {
    '/categories': 'categories',
    '/cart': 'cart',
    '/favorites': 'favorites',
    '/profile': 'profile',
  };
  final tab = tabRoutes[route];
  if (tab != null) {
    router.go('/?tab=$tab');
    return;
  }
  router.push(route);
}

/// Replays a boot-time deferred deep link (clipboard install attribution) or an
/// onboarding/tutorial hand-off: lands on Home first, then pushes the target so
/// Back always has a real origin underneath.
void replayCustomerDeepLink(GoRouter router, String? route) {
  final target = route?.trim();
  if (target == null || target.isEmpty || target == '/') {
    router.go('/');
    return;
  }
  router.go('/');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigateCustomerRoute(router, target);
  });
}

/// Customer-side navigation. The shell hosts the bottom tabs; the rest are
/// pushed on top via `context.push(...)`. Filters propagate via query params
/// so deep links like `/product-list?categoryId=sofas` reproduce the same
/// state.
GoRouter buildCustomerRouter() {
  return GoRouter(
    // Home is always the router root so share / universal links can push product
    // detail on top (Back → home). Deferred clipboard links replay via
    // [replayCustomerDeepLink] after onboarding clears.
    initialLocation: '/',
    navigatorKey: customerNavigatorKey,
    observers: [
      AppNavigationLogger(),
      // Auto screen_view + Crashlytics breadcrumbs on every route push.
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    // First-launch onboarding gate. Runs on every navigation: until the user
    // finishes the 3D onboarding, route them to `/onboarding` regardless of the
    // intended destination. A declarative redirect (not an imperative push)
    // avoids racing the Navigator's mount order under `_ModeRouter`'s crossfade.
    redirect: (context, state) {
      // Locale-prefixed Universal Links (AASA allows /*/product/*) → canonical
      // in-app routes. Bare /product/:id is handled by its own GoRoute.
      final path = state.uri.path;
      final productLocale = RegExp(
        r'^/(uz|ru|en)/product/([^/]+)/?$',
      ).firstMatch(path);
      if (productLocale != null) {
        return '/product-detail/${productLocale.group(2)}';
      }
      final shopLocale = RegExp(
        r'^/(uz|ru|en)/shop/([^/]+)/?$',
      ).firstMatch(path);
      if (shopLocale != null) {
        return '/shop/${shopLocale.group(2)}';
      }

      // First-launch gate → the 3D onboarding (replaces the legacy /tutorial
      // gate). Shows exactly once; `onboarding_seen` flips on Skip / Get Started.
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!customer_onboarding.isOnboardingSeen() && !atOnboarding) {
        return '/onboarding';
      }
      if (customer_onboarding.isOnboardingSeen() && atOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        // `?tab=` deep-links straight into a bottom-nav tab (e.g.
        // `/?tab=profile` from a verification-verdict notification) so the
        // user lands on the real tab — bottom nav visible — not a pushed
        // standalone copy of the screen.
        builder: (context, state) => CustomerHomeShell(
          initialTab: switch (state.uri.queryParameters['tab']) {
            'categories' => 1,
            'cart' => 2,
            'favorites' => 3,
            'profile' => 4,
            _ => null,
          },
        ),
      ),
      GoRoute(
        path: '/tutorial',
        // On completion, replay any deferred deep link captured at boot (a
        // shared product the user installed the app to see) instead of just
        // dropping them on home. `take()` clears it so it can't fire twice.
        builder: (context, state) => CustomerTutorialScreen(
          onDone: () => replayCustomerDeepLink(
            GoRouter.of(context),
            DeferredDeepLink.take(),
          ),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        // First-launch 3D onboarding (the redirect gate above lands here).
        // On finish, replay any deferred deep link captured at boot, else home.
        builder: (context, state) => customer_onboarding.OnboardingScreen(
          onDone: () => replayCustomerDeepLink(
            GoRouter.of(context),
            DeferredDeepLink.take(),
          ),
        ),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/product-list',
        builder: (context, state) {
          final categoryId = state.uri.queryParameters['categoryId'] ?? '';
          final subcategoryId = state.uri.queryParameters['subcategoryId'];
          final categoryName =
              state.uri.queryParameters['categoryName'] ?? 'Products';
          return BlocProvider(
            create: (_) => ProductListCubit(
              sl<ProductDataSource>(),
              sl<CategoryDataSource>(),
            )..load(categoryId: categoryId, subcategoryId: subcategoryId),
            child: ProductListScreen(
              categoryId: categoryId,
              subcategoryId: subcategoryId,
              categoryName: categoryName,
            ),
          );
        },
      ),
      GoRoute(
        path: '/product-detail/:id',
        builder: (context, state) {
          final product = state.extra as ProductModel?;
          if (product != null) {
            return CatalogProductDetailScreen(product: product);
          }
          return _ProductDetailLoader(id: state.pathParameters['id']!);
        },
      ),
      // Inbound web deep-link path. The public share URL and the native
      // Universal Link / App Link is `woody.uz/product/:id`; Flutter's
      // platform deep linking delivers that path here. Redirect to the in-app
      // canonical detail route so there's a single product screen.
      GoRoute(
        path: '/product/:id',
        redirect: (context, state) =>
            '/product-detail/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/shop/:id',
        builder: (context, state) =>
            ShopProfileScreen(shopId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/chats',
        builder: (context, state) => ChatsListScreen(
          viewer: ChatSenderRole.customer,
          threadRouteBuilder: (c) => '/chats/${c.id}',
        ),
      ),
      // Open by chat id — used from the chat list.
      GoRoute(
        path: '/chats/:chatId',
        builder: (context, state) => ChatThreadScreen(
          viewer: ChatSenderRole.customer,
          chatId: state.pathParameters['chatId']!,
          onOpenOrder: (orderId) => context.push('/orders/$orderId'),
        ),
      ),
      // Open by order id — lazily creates the chat row if needed. Used
      // from the order detail screen so the customer can DM the seller
      // without first hopping through the chat list.
      GoRoute(
        path: '/orders/:orderId/chat',
        builder: (context, state) => ChatThreadScreen(
          viewer: ChatSenderRole.customer,
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      // Customer support — single per-user thread. Both the profile menu and
      // a push tap (FCM route="support") deep-link here.
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportChatScreen(),
      ),
      // AI interior-designer chat. The cubit loads persisted history instantly
      // on construction, so it's built per-route here (no DI singleton needed).
      GoRoute(
        path: '/ai-designer-chat',
        builder: (context, state) => BlocProvider.value(
          // Root-scope SINGLETON (see catalog_module): popping the screen must
          // NOT close it, so an in-flight AI request finishes + persists.
          value: sl<AiDesignerCubit>(),
          child: const AiAssistantChatScreen(),
        ),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final items = state.extra as List<CartItemModel>?;
          if (items == null || items.isEmpty) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: Text('Savatch bo\'sh — orqaga qayting'),
              ),
            );
          }
          return CheckoutScreen(items: items);
        },
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersHistoryScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            OrderDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/seller/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        // Both the app-bar bell and push-tap deep-links land here. Routed to
        // the cubit-backed customer screen (resilient: a 401/guest personal
        // fetch degrades to the public news feed instead of a full error) —
        // the legacy shared NotificationsScreen is no longer wired.
        path: '/notifications',
        builder: (context, state) =>
            const customer_notifications.NotificationsScreen(),
      ),
      // ---- Broadcast deep-link placeholders -------------------------------
      // Promo / news / system-alert notifications resolve to these routes
      // via `determineRouteFor` in notifications_screen.dart. Until the
      // dedicated screens land, all three share `BroadcastPlaceholderScreen`
      // — see its dartdoc for the rationale. Two GoRoutes per kind (with
      // and without id) so the routing helper's payload-id fallback still
      // resolves cleanly.
      GoRoute(
        path: '/promo',
        builder: (context, state) =>
            const BroadcastPlaceholderScreen(kind: BroadcastKind.promo),
      ),
      GoRoute(
        path: '/promo/:id',
        builder: (context, state) => BroadcastPlaceholderScreen(
          kind: BroadcastKind.promo,
          referenceId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/news',
        builder: (context, state) =>
            const BroadcastPlaceholderScreen(kind: BroadcastKind.news),
      ),
      GoRoute(
        path: '/news/:id',
        builder: (context, state) => BroadcastPlaceholderScreen(
          kind: BroadcastKind.news,
          referenceId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/system-alert',
        builder: (context, state) =>
            const BroadcastPlaceholderScreen(kind: BroadcastKind.systemAlert),
      ),
      GoRoute(
        path: '/customer/notifications',
        builder: (context, state) =>
            const customer_notifications.NotificationsScreen(),
      ),
      GoRoute(
        path: '/debug/notifications',
        builder: (context, state) =>
            const NotificationSimulatorScreen(currentMode: AppMode.customer),
      ),
    ],
  );
}

class _ProductDetailLoader extends StatelessWidget {
  const _ProductDetailLoader({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final source = sl<ProductDataSource>();
    // Peek the cache synchronously so a previously-viewed product paints
    // instantly on a re-visit (favourites → detail, cart → detail, deep-link
    // back into a recently-seen item). The network fetch still runs to
    // refresh stock/price/discount; `FutureBuilder.initialData` plus the
    // resolved future means the screen never flashes a spinner when the
    // cache hits.
    final cached = source.peekById(id);
    return FutureBuilder<ProductModel>(
      future: source.getById(id),
      initialData: cached,
      builder: (context, snap) {
        if (snap.hasData) {
          return CatalogProductDetailScreen(product: snap.data!);
        }
        if (snap.hasError) {
          // Reachable via deep links (a shared link to a deleted/invalid
          // product, or an offline fetch) — show a friendly message + a way
          // home instead of leaking a raw backend error string.
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('product.not_found'), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: Text(tr('product.back_home')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const Scaffold(body: Center(child: BrandLoadingIndicator()));
      },
    );
  }
}
