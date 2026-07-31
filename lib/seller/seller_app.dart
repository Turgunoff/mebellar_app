import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../config/app_config.dart';
import '../config/app_mode.dart';
import '../core/auth/session_revalidator.dart';
import '../core/connectivity/network_cubit.dart';
import '../core/deep_links/deep_link_service.dart';
import '../core/di/service_locator.dart';
import '../core/i18n/i18n.dart';
import '../core/logging/app_navigation_logger.dart';
import '../core/logging/app_logger.dart';
import '../core/notifications/notification_handler.dart';
import '../core/theme/app_theme.dart' show appSystemOverlay;
import '../core/theme/seller_theme.dart';
import '../core/theme/theme_cubit.dart';
import '../core/updates/app_update_gate.dart';
import '../main.dart' show AppLocaleScope;
import '../shared/chat/bloc/total_unread_chats_cubit.dart';
import '../shared/models/chat.dart';
import '../shared/payments/payment_recovery_gate.dart';
import '../shared/payments/pending_payment.dart';
import '../shared/payments/seller_payment_refresh.dart';
import '../shared/repositories/chat_repository.dart';
import '../shared/widgets/network_overlay_wrapper.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/orders/bloc/seller_orders_bloc.dart';
import 'features/orders/screens/seller_orders_screen.dart';
import 'features/products/screens/seller_products_screen.dart';
import 'features/profile/profile_screen.dart';
import 'seller_router.dart';
import 'widgets/seller_bottom_nav.dart';

class SellerApp extends StatefulWidget {
  const SellerApp({super.key});

  @override
  State<SellerApp> createState() => _SellerAppState();
}

class _SellerAppState extends State<SellerApp> with WidgetsBindingObserver {
  /// Built only when [AppConfig.sellerUsesGoRouter] is on; the legacy shell
  /// path leaves this null and routes imperatively via [sellerNavigatorKey].
  GoRouter? _router;

  static const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (AppConfig.sellerUsesGoRouter) {
      _router = buildSellerRouter();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingRoute();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A push tapped while backgrounded stashed a pending route with no fresh
    // initState to consume it — pick it up on resume.
    if (state == AppLifecycleState.resumed) {
      // Re-validate the session on resume so a deleted/blocked seller is
      // force-logged-out immediately instead of lingering on stale screens.
      revalidateSessionOnResume();
      _consumePendingRoute();
    }
  }

  void _consumePendingRoute() {
    // Same two-channel resolution as the customer shell:
    //   1. [DeepLinkService] — in-app inbox routing interceptor wrote here
    //      before triggering the Phoenix.rebirth that landed us in seller.
    //   2. [NotificationHandler] — system-tray push tap stashed a seller
    //      route while the user was in customer mode.
    // The DeepLinkService route wins when both are present.
    String? route;
    if (sl.isRegistered<DeepLinkService>()) {
      route = sl<DeepLinkService>().consumePendingRoute();
    }
    if (route == null && sl.isRegistered<NotificationHandler>()) {
      route = sl<NotificationHandler>().consumeFor(AppMode.seller.name)?.route;
    }
    if (route == null) return;
    final router = _router;
    if (router != null) {
      // push (not go) so the deep-link target sits on top of the seller home
      // base and Back returns there instead of dead-ending.
      router.push(route);
    } else {
      // Legacy path: push onto the global navigator. Unmapped routes no-op.
      sellerNavigatorKey.currentState?.pushNamed(route);
    }
  }

  // No silent redirect-on-missing-auth here: the saved `app_mode` is the
  // user's explicit choice and we honor it. If the session is later found
  // to be missing, individual seller screens guard themselves rather than
  // the shell yanking the user back to customer mode.

  @override
  Widget build(BuildContext context) {
    // Reuse the global ThemeCubit (Hive `isDarkMode`) so toggling dark mode
    // applies to both customer and seller modes from one setting.
    return BlocProvider<NetworkCubit>.value(
      value: sl<NetworkCubit>(),
      child: BlocProvider<ThemeCubit>.value(
        value: sl<ThemeCubit>(),
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, themeState) => _router != null
              ? _buildRouterApp(context, themeState.themeMode)
              : _buildLegacyApp(context, themeState.themeMode),
        ),
      ),
    );
  }

  /// ROADMAP B.3 — `go_router`-driven seller shell.
  Widget _buildRouterApp(BuildContext context, ThemeMode themeMode) {
    return MaterialApp.router(
      title: 'Woody Seller',
      debugShowCheckedModeBanner: false,
      theme: sellerLightTheme,
      darkTheme: sellerDarkTheme,
      themeMode: themeMode,
      routerConfig: _router!,
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: AppTranslations.supportedLocales,
      locale: AppLocaleScope.of(context).value,
      builder: _appBuilder,
    );
  }

  /// Legacy imperative shell — kept behind the flag so the migration can be
  /// reverted without a code change while debugging.
  Widget _buildLegacyApp(BuildContext context, ThemeMode themeMode) {
    return MaterialApp(
      title: 'Woody Seller',
      debugShowCheckedModeBanner: false,
      theme: sellerLightTheme,
      darkTheme: sellerDarkTheme,
      themeMode: themeMode,
      navigatorKey: sellerNavigatorKey,
      navigatorObservers: [AppNavigationLogger()],
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: AppTranslations.supportedLocales,
      locale: AppLocaleScope.of(context).value,
      home: const SellerHomeShell(),
      builder: _appBuilder,
    );
  }

  Widget _appBuilder(BuildContext context, Widget? child) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: appSystemOverlay(Theme.of(context).brightness),
      // AppUpdateGate is outermost so its force-update overlay paints above
      // the network banner and every route.
      child: AppUpdateGate(
        child: NetworkOverlayWrapper(
          // Reconciles an in-flight AR-token / subscription payment on return
          // (resume poll + cold-start probe). No deep-link target — the result
          // card just confirms settlement; the seller's balance/tariff screens
          // refresh on their own.
          child: PaymentRecoveryGate(
            onReconciled: (payment, outcome) {
              if (outcome == PaymentOutcome.paid) {
                SellerPaymentRefreshHub.instance.notify(payment.kind);
              }
            },
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Legacy bottom-nav shell — used only when [AppConfig.sellerUsesGoRouter] is
/// off. The `go_router` path uses [SellerRouterShell] instead. Delete this
/// once the migration is permanent (ROADMAP B.3).
class SellerHomeShell extends StatefulWidget {
  const SellerHomeShell({super.key});

  @override
  State<SellerHomeShell> createState() => _SellerHomeShellState();
}

class _SellerHomeShellState extends State<SellerHomeShell> {
  int _index = 0;

  /// Stable English tab names for the nav log — independent of the active UI
  /// language so the console stream reads consistently while debugging.
  static const _tabNames = [
    'Dashboard',
    'Products',
    'Orders',
    'Analytics',
    'Profile',
  ];

  Widget _bodyForTab(int i) {
    // Mock-mode: every seller tab is unlocked regardless of verification
    // status, so the populated dashboard isn't undercut by lock screens on
    // adjacent tabs.
    return switch (i) {
      0 => SellerDashboardScreen(
        onSeeAllOrders: () => setState(() => _index = 2),
      ),
      1 => const SellerProductsScreen(),
      2 => const SellerOrdersScreen(),
      3 => const SellerAnalyticsScreen(),
      4 => const SellerProfileScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Mirrors SellerRouterShell: orders + unread-chats badges stay live at
    // the shell level regardless of which tab is painted.
    return MultiBlocProvider(
      providers: [
        BlocProvider<SellerOrdersBloc>.value(value: sl<SellerOrdersBloc>()),
        BlocProvider<TotalUnreadChatsCubit>(
          create: (_) => TotalUnreadChatsCubit(
            sl<ChatRepository>(),
            ChatSenderRole.seller,
          ),
        ),
      ],
      child: BlocBuilder<SellerOrdersBloc, SellerOrdersState>(
        buildWhen: (prev, curr) => prev.badgeCount != curr.badgeCount,
        builder: (context, ordersState) => Scaffold(
          appBar: null,
          body: Column(children: [Expanded(child: _bodyForTab(_index))]),
          bottomNavigationBar: BlocBuilder<TotalUnreadChatsCubit, int>(
            builder: (context, unreadChats) => SellerBottomNav(
              currentIndex: _index,
              onChanged: (i) {
                if (i != _index) {
                  AppNavigationLogger.logTabSwitch(i, _tabNames[i]);
                }
                setState(() => _index = i);
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
    );
  }
}
