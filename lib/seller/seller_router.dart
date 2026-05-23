import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../core/di/service_locator.dart';
import '../core/i18n/i18n.dart';
import '../core/logging/console_nav_observer.dart';
import '../core/logging/talker.dart';
import '../shared/models/seller_product.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/orders/bloc/seller_orders_bloc.dart';
import 'features/orders/screens/order_details_screen.dart';
import 'features/orders/screens/seller_orders_screen.dart';
import 'features/products/screens/product_form_screen.dart';
import '../shared/chat/screens/chat_thread_screen.dart';
import '../shared/chat/screens/chats_list_screen.dart';
import '../shared/models/chat.dart';
import 'features/products/screens/seller_product_detail_screen.dart';
import 'features/products/screens/seller_products_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/reviews/screens/reviews_screen.dart';
import 'features/settings/screens/services_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/settings/screens/shop_settings_screen.dart';
import 'features/tariff/screens/tariff_history_screen.dart';
import 'features/tariff/screens/tariff_screen.dart';
import 'widgets/seller_bottom_nav.dart';

/// Root navigator for seller mode. Full-screen routes (product detail/form,
/// order detail, settings sub-pages, tariff, ...) render on this navigator so
/// they sit *above* the bottom-nav shell.
final GlobalKey<NavigatorState> sellerRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sellerRootNavigator');

/// Builds the seller-mode [GoRouter] (ROADMAP B.3).
///
/// The five bottom-nav tabs are branches of a [StatefulShellRoute.indexedStack]
/// so each tab keeps its own navigation stack across switches. Detail and
/// settings pages are declared as sub-routes but pinned to
/// [sellerRootNavigatorKey], which makes them full-screen pushes without the
/// bottom nav.
GoRouter buildSellerRouter() {
  return GoRouter(
    navigatorKey: sellerRootNavigatorKey,
    initialLocation: '/seller/dashboard',
    observers: [TalkerRouteObserver(talker), ConsoleNavObserver()],
    errorBuilder: (context, state) =>
        _SellerRouteError(location: state.uri.toString()),
    routes: [
      // Bare `/seller` → land on the dashboard tab.
      GoRoute(
        path: '/seller',
        redirect: (_, _) => '/seller/dashboard',
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            SellerRouterShell(shell: navigationShell),
        branches: [
          // --- Tab 0: Dashboard ------------------------------------------
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/seller/dashboard',
                builder: (context, state) => SellerDashboardScreen(
                  // Switching the active branch — `context.go` to the orders
                  // path swaps tabs without growing the stack.
                  onSeeAllOrders: () => context.go('/seller/orders'),
                ),
              ),
            ],
          ),

          // --- Tab 1: Products -------------------------------------------
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/seller/products',
                builder: (_, _) => const SellerProductsScreen(),
                routes: [
                  // `new` is declared before `:id` so it is matched first
                  // (otherwise `:id` would capture the literal "new").
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: sellerRootNavigatorKey,
                    builder: (_, _) => const ProductFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: sellerRootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      // The product is passed as GoRouter `extra` from the
                      // list screen; deep-linking to this path without it
                      // is not supported yet — surface a clear error instead
                      // of crashing on the cast.
                      final product = state.extra;
                      if (product is! SellerProduct) {
                        return const Scaffold(
                          body: Center(
                            child: Text(
                              "Mahsulot ma'lumotlari topilmadi",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return SellerProductDetailScreen(
                        product: product,
                        onEdit: () =>
                            context.push('/seller/products/$id/edit'),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: sellerRootNavigatorKey,
                        builder: (_, _) => const ProductFormScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // --- Tab 2: Orders ---------------------------------------------
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/seller/orders',
                builder: (_, _) => const SellerOrdersScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: sellerRootNavigatorKey,
                    builder: (context, state) => OrderDetailsScreen(
                      orderId: state.pathParameters['id']!,
                      ordersBloc: sl<SellerOrdersBloc>(),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // --- Tab 3: Analytics ------------------------------------------
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/seller/analytics',
                builder: (_, _) => const SellerAnalyticsScreen(),
              ),
            ],
          ),

          // --- Tab 4: Profile --------------------------------------------
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/seller/profile',
                builder: (_, _) => const SellerProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    parentNavigatorKey: sellerRootNavigatorKey,
                    builder: (_, _) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'shop-settings',
                    parentNavigatorKey: sellerRootNavigatorKey,
                    builder: (_, _) => const ShopSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'services',
                    parentNavigatorKey: sellerRootNavigatorKey,
                    builder: (_, _) => const SellerServicesScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // --- Full-screen routes outside the shell --------------------------
      GoRoute(
        path: '/seller/tariff',
        builder: (_, _) => const TariffScreen(),
        routes: [
          GoRoute(
            path: 'history',
            builder: (_, _) => const TariffHistoryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/seller/reviews',
        builder: (_, _) => const ReviewsScreen(),
      ),
      GoRoute(
        path: '/seller/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/seller/chats',
        builder: (_, _) => ChatsListScreen(
          viewer: ChatSenderRole.seller,
          threadRouteBuilder: (c) => '/seller/chats/${c.id}',
        ),
      ),
      GoRoute(
        path: '/seller/chats/:chatId',
        builder: (context, state) => ChatThreadScreen(
          viewer: ChatSenderRole.seller,
          chatId: state.pathParameters['chatId']!,
          onOpenOrder: (orderId) =>
              context.push('/seller/orders/$orderId'),
        ),
      ),
      // Seller's order detail jumps here — chat row must already exist
      // (customer creates it on first send), so this calls `getChat`
      // by order indirectly through the bootstrap.
      GoRoute(
        path: '/seller/orders/:orderId/chat',
        builder: (context, state) => ChatThreadScreen(
          viewer: ChatSenderRole.seller,
          orderId: state.pathParameters['orderId']!,
        ),
      ),
    ],
  );
}

/// Bottom-nav shell hosting the five [StatefulShellRoute] branches.
///
/// Provides [SellerOrdersBloc] at the shell level so both the badge and all
/// child screens share the same singleton instance.
class SellerRouterShell extends StatelessWidget {
  const SellerRouterShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SellerOrdersBloc>.value(
      value: sl<SellerOrdersBloc>(),
      child: BlocBuilder<SellerOrdersBloc, SellerOrdersState>(
        buildWhen: (prev, curr) => prev.badgeCount != curr.badgeCount,
        builder: (context, ordersState) => Scaffold(
          body: shell,
          bottomNavigationBar: SellerBottomNav(
            currentIndex: shell.currentIndex,
            onChanged: (i) => shell.goBranch(
              i,
              initialLocation: i == shell.currentIndex,
            ),
            items: [
              SellerNavItem(
                icon: Iconsax.element_3,
                label: tr('seller.tab_dashboard'),
              ),
              SellerNavItem(
                  icon: Iconsax.box, label: tr('seller.tab_products')),
              SellerNavItem(
                icon: Iconsax.shopping_bag,
                label: tr('seller.tab_orders'),
                badge: ordersState.badgeCount,
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
  }
}

/// Fallback shown when a deep link resolves to an unmapped seller path.
class _SellerRouteError extends StatelessWidget {
  const _SellerRouteError({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sahifa topilmadi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 12),
              Text(location, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/seller/dashboard'),
                child: Text(tr('seller.tab_dashboard')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
