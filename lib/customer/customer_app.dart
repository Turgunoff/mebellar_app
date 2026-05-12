import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/auth/auth_cubit.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../config/app_mode.dart';
import '../core/deep_links/deep_link_service.dart';
import '../core/di/service_locator.dart';
import '../core/i18n/i18n.dart';
import '../core/logging/debug_talker_overlay.dart';
import '../core/logging/talker.dart';
import '../core/notifications/notification_handler.dart';
import '../core/connectivity/network_cubit.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_cubit.dart';
import 'features/categories/bloc/categories_bloc.dart';
import '../main.dart' show AppLocaleScope;
import '../shared/repositories/notifications_repository.dart';
import '../shared/widgets/network_overlay_wrapper.dart';
import 'features/cart/bloc/cart_bloc.dart';
import 'features/cart/screens/cart_screen.dart';
import 'features/orders/cubit/profile_orders_cubit.dart';
import 'features/profile/cubit/profile_cubit.dart';
import 'features/categories/screens/categories_screen.dart';
import 'features/favorites/bloc/favorites_bloc.dart';
import 'features/favorites/screens/favorites_screen.dart';
import 'features/home/bloc/home_bloc.dart';
import 'features/home/screens/home_screen.dart';
import 'features/home/widgets/premium/premium_tokens.dart';
import 'features/profile/screens/profile_guest_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'router.dart';
import 'widgets/glass_bottom_nav.dart';

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key});

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  late final GoRouter _router = buildCustomerRouter();
  StreamSubscription<DeepLinkTarget>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingRoute();
    });
    if (sl.isRegistered<DeepLinkService>()) {
      _deepLinkSub = sl<DeepLinkService>().watch().listen(_onDeepLink);
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  void _consumePendingRoute() {
    if (!sl.isRegistered<NotificationHandler>()) return;
    final route =
        sl<NotificationHandler>().consumeFor(AppMode.customer.name);
    if (route != null && mounted) _router.go(route);
  }

  /// Listens for incoming app/universal links. Sprint 11 mock: the simulator
  /// screen calls `DeepLinkService.handleUri(...)` and we route only when
  /// the target is customer-mode. Cross-mode links go through
  /// `NotificationHandler` (saved as a pending route) so the same machinery
  /// that handles push deep-links is reused.
  void _onDeepLink(DeepLinkTarget target) {
    if (!mounted) return;
    if (target.mode == AppMode.customer) {
      _router.go(target.route);
    } else if (sl.isRegistered<NotificationHandler>()) {
      sl<NotificationHandler>()
          .savePendingRoute(target.route, target.mode.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cart + Favorites BLoCs live in the customer scope (registered in DI),
    // but every BlocProvider/BlocConsumer in the widget tree expects to find
    // them via context.read. We expose them at the root of MaterialApp so
    // both the bottom-nav cart screen and any pushed product detail pick up
    // the same singleton.
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) => MultiBlocProvider(
        providers: [
          BlocProvider<CartBloc>.value(value: sl<CartBloc>()),
          BlocProvider<FavoritesBloc>.value(value: sl<FavoritesBloc>()),
          BlocProvider<CategoriesBloc>.value(value: sl<CategoriesBloc>()),
          BlocProvider<HomeBloc>.value(value: sl<HomeBloc>()),
          BlocProvider<NetworkCubit>.value(value: sl<NetworkCubit>()),
          BlocProvider<ProfileOrdersCubit>.value(
            value: sl<ProfileOrdersCubit>(),
          ),
          BlocProvider<ProfileCubit>.value(value: sl<ProfileCubit>()),
        ],
        child: MaterialApp.router(
          title: 'Woody',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeState.themeMode,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppTranslations.supportedLocales,
          locale: AppLocaleScope.of(context).value,
          routerConfig: _router,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: appSystemOverlay(Theme.of(context).brightness),
            child: NetworkOverlayWrapper(
              child: DebugTalkerOverlay(
                navigatorKey: customerNavigatorKey,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inherited handle a tab body can use to ask the shell to switch tabs
/// (e.g. the favorites empty state's "Katalogga o'tish" button jumps back
/// to Home instead of pushing a new route, which would hide the bottom
/// nav and break back-stack expectations).
class CustomerShellScope extends InheritedWidget {
  const CustomerShellScope({
    super.key,
    required this.goToTab,
    required super.child,
  });

  final void Function(int index) goToTab;

  static CustomerShellScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CustomerShellScope>();
    assert(scope != null, 'CustomerShellScope ancestor missing');
    return scope!;
  }

  @override
  bool updateShouldNotify(CustomerShellScope oldWidget) =>
      oldWidget.goToTab != goToTab;
}

/// Bottom-tab shell. All five tabs are mounted in an [IndexedStack] so each
/// keeps its scroll/listener state when the user switches tabs and comes
/// back — flipping Home → Favorites → Home no longer resets the home feed
/// to the top.
class CustomerHomeShell extends StatefulWidget {
  const CustomerHomeShell({super.key});

  @override
  State<CustomerHomeShell> createState() => _CustomerHomeShellState();
}

class _CustomerHomeShellState extends State<CustomerHomeShell> {
  int _index = 0;

  void _goToTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  String _titleForTab(int i) {
    return switch (i) {
      0 => 'Woody',
      1 => tr('home.categories'),
      2 => tr('cart.title'),
      3 => 'Sevimlilar',
      4 => tr('profile.title'),
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack mounts every tab once and keeps inactive ones in the tree
    // (just hidden), so each tab's State — and any ScrollController inside —
    // survives navigation. No `AutomaticKeepAliveClientMixin` is needed: the
    // children are never disposed by IndexedStack itself.
    final tabs = <Widget>[
      const HomeScreen(),
      const CategoriesScreen(),
      const CartScreen(),
      const FavoritesScreen(),
      BlocBuilder<AuthCubit, AppAuthState>(
        builder: (context, state) => state is AppAuthAuthenticated
            ? const ProfileScreen()
            : const ProfileGuestScreen(),
      ),
    ];
    return CustomerShellScope(
      goToTab: _goToTab,
      child: Scaffold(
      extendBody: true,
      // Every premium tab renders its own header — suppress the shell AppBar
      // to avoid double titles.
      appBar: (_index == 0 ||
              _index == 1 ||
              _index == 2 ||
              _index == 3 ||
              _index == 4)
          ? null
          : AppBar(
              title: Text(_titleForTab(_index)),
              actions: const [
                _NotificationsAppBarAction(),
              ],
            ),
      // The connectivity banner is mounted globally by NetworkOverlayWrapper
      // in MaterialApp.builder, so it survives route changes and we don't
      // need a per-shell Column wrapper here.
      body: IndexedStack(
        index: _index,
        children: tabs,
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _index,
        onTap: _goToTab,
        items: [
          GlassNavItem(
            label: tr('home.title'),
            iconBuilder: (_, active) =>
                _NavIcon(icon: Iconsax.home_2, isActive: active),
          ),
          GlassNavItem(
            label: tr('home.categories'),
            iconBuilder: (_, active) =>
                _NavIcon(icon: Iconsax.element_3, isActive: active),
          ),
          GlassNavItem(
            label: tr('cart.title'),
            iconBuilder: (_, active) => BlocBuilder<CartBloc, CartState>(
              buildWhen: (a, b) => a.totalUnits != b.totalUnits,
              builder: (context, state) {
                final units = state.totalUnits;
                final icon = _NavIcon(
                  icon: Iconsax.shopping_bag,
                  isActive: active,
                );
                if (units == 0) return icon;
                return Badge.count(count: units, child: icon);
              },
            ),
          ),
          GlassNavItem(
            label: 'Sevimlilar',
            iconBuilder: (_, active) =>
                _NavIcon(icon: Iconsax.heart, isActive: active),
          ),
          GlassNavItem(
            label: tr('profile.title'),
            iconBuilder: (_, active) =>
                _NavIcon(icon: Iconsax.profile_circle, isActive: active),
          ),
        ],
      ),
    ),
    );
  }
}

/// Single nav-bar glyph: terracotta when active, soft grey otherwise.
class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.isActive});

  final IconData icon;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: 26,
      color: isActive ? PremiumTokens.accent : const Color(0xFF9E9E9E),
    );
  }
}

/// AppBar bell icon with a per-mode unread badge. Tapping opens the
/// shared notifications screen.
class _NotificationsAppBarAction extends StatelessWidget {
  const _NotificationsAppBarAction();

  void _open(BuildContext context) {
    context.push('/notifications');
  }

  @override
  Widget build(BuildContext context) {
    if (!sl.isRegistered<NotificationsRepository>()) {
      return IconButton(
        tooltip: tr('notifications.title'),
        icon: const Icon(Icons.notifications_outlined),
        onPressed: () => _open(context),
      );
    }
    return StreamBuilder<int>(
      stream: sl<NotificationsRepository>()
          .watchUnread(mode: AppMode.customer.name),
      initialData: sl<NotificationsRepository>()
          .unreadCount(mode: AppMode.customer.name),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return IconButton(
          tooltip: tr('notifications.title'),
          icon: count == 0
              ? const Icon(Icons.notifications_outlined)
              : Badge.count(
                  count: count,
                  child: const Icon(Icons.notifications_outlined),
                ),
          onPressed: () => _open(context),
        );
      },
    );
  }
}

