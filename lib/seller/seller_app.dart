import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../config/app_mode.dart';
import '../core/connectivity/network_cubit.dart';
import '../core/deep_links/deep_link_service.dart';
import '../core/di/service_locator.dart';
import '../core/i18n/i18n.dart';
import '../core/logging/console_nav_observer.dart';
import '../core/logging/talker.dart';
import '../core/notifications/notification_handler.dart';
import '../core/theme/app_theme.dart' show appSystemOverlay;
import '../core/theme/seller_theme.dart';
import '../main.dart' show AppLocaleScope;
import '../shared/widgets/network_overlay_wrapper.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/orders/screens/seller_orders_screen.dart';
import 'features/products/screens/seller_products_screen.dart';
import 'features/profile/profile_screen.dart';
import 'widgets/seller_bottom_nav.dart';

class SellerApp extends StatefulWidget {
  const SellerApp({super.key});

  @override
  State<SellerApp> createState() => _SellerAppState();
}

class _SellerAppState extends State<SellerApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingRoute();
    });
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
      route = sl<NotificationHandler>().consumeFor(AppMode.seller.name);
    }
    if (route == null) return;
    // SellerApp is a plain `MaterialApp` (no GoRouter), so we push via the
    // global navigator key wired into `MaterialApp.navigatorKey`. Routes
    // that aren't mapped in `onGenerateRoute` will no-op silently — fine
    // for the dummy-route phase of the Sprint.
    sellerNavigatorKey.currentState?.pushNamed(route);
  }

  // No silent redirect-on-missing-auth here: the saved `app_mode` is the
  // user's explicit choice and we honor it. If the session is later found
  // to be missing, individual seller screens guard themselves (e.g. by
  // showing a login banner or gated tab) rather than the shell yanking
  // the user back to customer mode and overwriting the persisted choice.

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NetworkCubit>.value(
      value: sl<NetworkCubit>(),
      child: MaterialApp(
        title: 'Woody Seller',
        debugShowCheckedModeBanner: false,
        theme: sellerLightTheme,
        darkTheme: sellerDarkTheme,
        navigatorKey: sellerNavigatorKey,
        navigatorObservers: [
          TalkerRouteObserver(talker),
          ConsoleNavObserver(),
        ],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppTranslations.supportedLocales,
        locale: AppLocaleScope.of(context).value,
        home: const SellerHomeShell(),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: appSystemOverlay(Theme.of(context).brightness),
          child: NetworkOverlayWrapper(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class SellerHomeShell extends StatefulWidget {
  const SellerHomeShell({super.key});

  @override
  State<SellerHomeShell> createState() => _SellerHomeShellState();
}

class _SellerHomeShellState extends State<SellerHomeShell> {
  int _index = 0;

  Widget _bodyForTab(int i) {
    // Mock-mode: every seller tab is unlocked regardless of verification
    // status, so the populated dashboard isn't undercut by lock screens on
    // adjacent tabs. Re-introduce the `_approved` gate here when wiring this
    // back up to a real verification flow.
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
    return Scaffold(
      // Every seller tab now renders its own premium header in-body, so the
      // shell never paints an AppBar. This is what keeps the surface free of
      // M3's teal-seeded surface tint on screens like Profile.
      appBar: null,
      // Connectivity banner is mounted once at MaterialApp.builder via
      // NetworkOverlayWrapper, so it doesn't need to live inside each shell.
      body: Column(
        children: [
          Expanded(child: _bodyForTab(_index)),
        ],
      ),
      bottomNavigationBar: SellerBottomNav(
        currentIndex: _index,
        onChanged: (i) => setState(() => _index = i),
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
    );
  }
}
