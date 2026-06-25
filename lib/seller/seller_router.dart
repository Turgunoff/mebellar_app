import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../core/auth/auth_cubit.dart';
import '../core/auth/auth_repository.dart';
import '../core/di/service_locator.dart';
import '../core/i18n/i18n.dart';
import '../core/logging/app_navigation_logger.dart';
import '../core/logging/talker.dart';
import '../core/storage/app_settings.dart';
import 'features/welcome/screens/seller_welcome_screen.dart';
import '../shared/models/seller_product.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/orders/bloc/seller_orders_bloc.dart';
import 'features/orders/screens/order_details_screen.dart';
import 'features/orders/screens/seller_orders_screen.dart';
import 'features/products/screens/product_form_screen.dart';
import '../shared/chat/bloc/total_unread_chats_cubit.dart';
import '../shared/chat/screens/chat_thread_screen.dart';
import '../shared/chat/screens/chats_list_screen.dart';
import '../shared/models/chat.dart';
import '../shared/repositories/chat_repository.dart';
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
    observers: [
      TalkerRouteObserver(talker),
      AppNavigationLogger(),
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    errorBuilder: (context, state) =>
        _SellerRouteError(location: state.uri.toString()),
    routes: [
      // Bare `/seller` → land on the dashboard tab.
      GoRoute(path: '/seller', redirect: (_, _) => '/seller/dashboard'),

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
                        return Scaffold(
                          body: Center(
                            child: Text(
                              tr('seller.product_data_not_found'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return SellerProductDetailScreen(
                        product: product,
                        onEdit: () => context.push('/seller/products/$id/edit'),
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
      // One-time celebratory welcome. Lives on the root navigator (above the
      // shell), so it covers the bottom nav and the shell's back-button
      // PopScope never sees these presses. The gate in [SellerRouterShell]
      // pushes it; tapping "Boshlash" flips the per-seller flag and pops.
      GoRoute(
        path: '/seller/welcome',
        builder: (context, state) {
          return SellerWelcomeScreen(
            onContinue: () {
              // Record server-side that the one-time bonus screen was seen, so
              // it never replays after a reinstall / device change. Best-effort
              // — a failed write just means it may show once more next launch.
              unawaited(
                sl<AuthRepository>()
                    .setSellerAlertFlags(bonusScreenSeen: true)
                    .catchError((Object e, StackTrace st) {
                      talker.handle(
                        e,
                        st,
                        'seller welcome: mark bonus seen failed',
                      );
                    }),
              );
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/seller/dashboard');
              }
            },
          );
        },
      ),
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
          onOpenOrder: (orderId) => context.push('/seller/orders/$orderId'),
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
class SellerRouterShell extends StatefulWidget {
  const SellerRouterShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<SellerRouterShell> createState() => _SellerRouterShellState();
}

class _SellerRouterShellState extends State<SellerRouterShell> {
  /// Timestamp of the last system-back press while the Dashboard tab was
  /// active. Drives the double-back-to-exit gesture; cleared on every tab
  /// switch so the two presses must be consecutive on Dashboard.
  DateTime? _lastBackPress;

  /// Stable English tab names for the nav log — independent of the active UI
  /// language so the console stream reads consistently while debugging.
  static const _tabNames = [
    'Dashboard',
    'Products',
    'Orders',
    'Analytics',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    // Defer to after first paint: the welcome route is pushed on top of a
    // fully-built shell, so dismissing it reveals the real dashboard.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowWelcome());
  }

  /// First-entry gate for the celebratory welcome screen. A freshly-approved
  /// seller who hasn't seen it is routed to `/seller/welcome` exactly once;
  /// the server-side `bonus_screen_seen` flag flips when they tap "Boshlash".
  /// Because the "seen" state lives on the seller row (not local Hive), it
  /// survives reinstall / device change — so the celebration never replays.
  Future<void> _maybeShowWelcome() async {
    if (!mounted) return;
    final auth = sl<AuthCubit>().state;
    if (auth is! AppAuthAuthenticated) return;
    // Cheap pre-filter: reaching the seller shell already implies approval (the
    // boot guard demotes unapproved sellers to customer), but skipping the
    // call for a stale unapproved session costs nothing.
    if (!sl<AppSettings>().sellerApproved) return;
    // Decide off the server: only an approved seller who hasn't yet seen the
    // bonus screen gets it. Any failure just skips — the welcome is purely
    // celebratory and must never block entry to the dashboard.
    try {
      final me = await sl<AuthRepository>().fetchMe();
      if (!mounted) return;
      final seller = me.sellerProfile;
      if (seller == null || !seller.isApproved || seller.bonusScreenSeen) {
        return;
      }
      GoRouter.of(context).push('/seller/welcome', extra: auth.userId);
    } catch (e, st) {
      talker.handle(e, st, 'seller welcome gate /me failed');
    }
  }

  /// Full-screen detail/form/settings pages are pushed on
  /// [sellerRootNavigatorKey] *above* this shell, so the framework pops those
  /// first and this handler only fires at a branch root. Mirrors the customer
  /// shell: a non-Dashboard tab returns to Dashboard; on Dashboard the first
  /// press shows a hint and a second within 2 seconds exits the app.
  void _handleSystemBack() {
    final shell = widget.shell;
    if (shell.currentIndex != 0) {
      _lastBackPress = null;
      shell.goBranch(0);
      return;
    }
    final now = DateTime.now();
    final last = _lastBackPress;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tr('seller.exit_confirm_hint')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    return MultiBlocProvider(
      providers: [
        BlocProvider<SellerOrdersBloc>.value(value: sl<SellerOrdersBloc>()),
        // Shell-level so the Profile-tab nav badge and the in-profile
        // "Suhbatlar" row share one live unread count.
        BlocProvider<TotalUnreadChatsCubit>(
          create: (_) => TotalUnreadChatsCubit(
            sl<ChatRepository>(),
            ChatSenderRole.seller,
          ),
        ),
      ],
      child: BlocBuilder<SellerOrdersBloc, SellerOrdersState>(
        buildWhen: (prev, curr) => prev.badgeCount != curr.badgeCount,
        builder: (context, ordersState) => PopScope(
          // The shell is the root route — never let the framework pop it
          // straight to an app exit; `_handleSystemBack` decides what happens.
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleSystemBack();
          },
          child: Scaffold(
            body: shell,
            bottomNavigationBar: BlocBuilder<TotalUnreadChatsCubit, int>(
              builder: (context, unreadChats) => SellerBottomNav(
                currentIndex: shell.currentIndex,
                onChanged: (i) {
                  // A tap that actually changes tabs resets the exit gesture so
                  // a stale Dashboard back-press can't bleed into the new tab.
                  if (i != shell.currentIndex) {
                    _lastBackPress = null;
                    AppNavigationLogger.logTabSwitch(i, _tabNames[i]);
                  }
                  shell.goBranch(i, initialLocation: i == shell.currentIndex);
                },
                items: [
                  SellerNavItem(
                    icon: Iconsax.element_3_copy,
                    activeIcon: Iconsax.element_3,
                    label: tr('seller.tab_dashboard'),
                  ),
                  SellerNavItem(
                    icon: Iconsax.box_copy,
                    activeIcon: Iconsax.box,
                    label: tr('seller.tab_products'),
                  ),
                  SellerNavItem(
                    icon: Iconsax.shopping_bag_copy,
                    activeIcon: Iconsax.shopping_bag,
                    label: tr('seller.tab_orders'),
                    badge: ordersState.badgeCount,
                  ),
                  SellerNavItem(
                    icon: Iconsax.chart_2_copy,
                    activeIcon: Iconsax.chart_2,
                    label: tr('seller.tab_analytics'),
                  ),
                  SellerNavItem(
                    icon: Iconsax.user_copy,
                    activeIcon: Iconsax.user,
                    label: tr('profile.title'),
                    badge: unreadChats,
                  ),
                ],
              ),
            ),
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
      appBar: AppBar(title: Text(tr('seller.route_not_found_title'))),
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
