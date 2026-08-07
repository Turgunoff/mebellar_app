import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/auth/auth_cubit.dart';
import '../core/auth/session_revalidator.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../core/deeplink/deferred_deep_link_service.dart';
import '../config/app_mode.dart';
import '../config/screenshot_mode.dart';
import '../core/deep_links/deep_link_service.dart';
import '../core/di/service_locator.dart';
import '../core/i18n/i18n.dart';
import '../core/logging/app_navigation_logger.dart';
import '../core/logging/app_logger.dart';
import '../core/notifications/notification_handler.dart';
import '../core/notifications/push_service.dart';
import '../core/presence/presence_service.dart';
import '../core/services/facebook_analytics_service.dart';
import '../core/connectivity/network_cubit.dart';
import '../core/storage/hive_boxes.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_cubit.dart';
import '../core/updates/app_update_gate.dart';
import 'features/categories/bloc/categories_bloc.dart';
import 'features/support/bloc/support_unread_cubit.dart';
import 'features/support/repository/support_chat_repository.dart';
import '../main.dart' show AppLocaleScope;
import '../shared/chat/bloc/total_unread_chats_cubit.dart';
import '../shared/models/chat.dart';
import '../shared/models/notification_model.dart';
import '../shared/payments/payment_recovery_gate.dart';
import '../shared/payments/pending_payment.dart';
import '../shared/repositories/chat_repository.dart';
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
import 'features/orders/cubit/unpaid_order_cubit.dart';
import 'features/home/screens/home_screen.dart';
import '../core/theme/premium_tokens.dart';
import 'features/notifications/cubit/notifications_cubit.dart';
import 'features/profile/screens/profile_guest_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import '../customer/navigation/product_escape_hatch.dart';
import 'features/onboarding/screens/onboarding_screen.dart'
    as customer_onboarding;
import 'router.dart';
import 'widgets/glass_bottom_nav.dart';

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key});

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildCustomerRouter();
  StreamSubscription<DeepLinkTarget>? _deepLinkSub;
  bool _normalizedShareStack = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingRoute();
      _replayBootDeepLink();
      _normalizeColdShareStack();
    });
    if (sl.isRegistered<DeepLinkService>()) {
      _deepLinkSub = sl<DeepLinkService>().watch().listen(_onDeepLink);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A push tapped while the app was backgrounded saves a pending route, but
    // there's no fresh initState to consume it — pick it up on resume.
    if (state == AppLifecycleState.resumed) {
      // Re-validate the session: if the account was deleted/blocked while the
      // app sat in the background, the probe's 401 force-logs-out immediately
      // instead of leaving the user on stale, already-painted screens.
      revalidateSessionOnResume();
      _consumePendingRoute();
      if (sl.isRegistered<PresenceService>()) {
        sl<PresenceService>().onResumed();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      // Cancel the 5-min presence Timer in every non-foreground state so it
      // cannot fire (or retain) while backgrounded / OS-suspended.
      if (sl.isRegistered<PresenceService>()) {
        sl<PresenceService>().onPaused();
      }
    }
  }

  void _consumePendingRoute() {
    // Two independent pending-route channels can hold a destination at boot:
    //   1. [NotificationHandler] — written by system-tray push taps. Keyed
    //      by mode, so the customer shell only sees customer routes.
    //   2. [DeepLinkService.consumePendingRoute] — written by the in-app
    //      inbox routing interceptor when a cross-mode tap triggered a
    //      Phoenix.rebirth. It has no mode key (the rebirth already
    //      delivered the user to the right shell), so the first shell to
    //      mount after the rebirth consumes it.
    // The DeepLinkService route wins when both are present; that's the
    // route the user just explicitly tapped on.
    if (!mounted) return;
    String? route;
    if (sl.isRegistered<DeepLinkService>()) {
      route = sl<DeepLinkService>().consumePendingRoute();
    }
    if (route == null && sl.isRegistered<NotificationHandler>()) {
      final pending = sl<NotificationHandler>().consumeFor(
        AppMode.customer.name,
      );
      route = pending?.route;
      _refreshStateForNotificationKind(pending?.kind);
    }
    // push (not go) so the deep-link target sits ON TOP of home — the router's
    // initialLocation is '/', so the stack becomes [home, target] and Back
    // returns to home instead of dead-ending on a rootless screen. Tab
    // destinations (e.g. /profile) are the exception: the helper switches
    // the shell tab instead.
    if (route != null) navigateCustomerRoute(_router, route);
  }

  /// Clipboard / first-install deferred product link — replay on top of home
  /// once the shell is mounted (skipped when onboarding still owns navigation).
  void _replayBootDeepLink() {
    if (!mounted) return;
    if (!customer_onboarding.isOnboardingSeen()) return;
    final route = DeferredDeepLink.take();
    if (route == null) return;
    replayCustomerDeepLink(_router, route);
  }

  /// Universal / App Link cold start can land on a lone product detail with no
  /// home underneath — replay through home so Back has somewhere to go.
  void _normalizeColdShareStack() {
    if (!mounted || _normalizedShareStack) return;
    _normalizedShareStack = true;
    if (!customer_onboarding.isOnboardingSeen()) return;
    final paths = currentStackPathsFor(_router);
    if (paths.length != 1 || paths.single != customerProductDetailPath) return;
    final loc = _router.routerDelegate.currentConfiguration.uri.path;
    if (!loc.startsWith('/product-detail/')) return;
    replayCustomerDeepLink(_router, loc);
  }

  /// A consumed seller-verdict notification means the cached `/me` seller
  /// status (the "Ko'rib chiqilmoqda" / "Tasdiqlandi" banner) is stale —
  /// refetch it so the profile the user lands on already shows the verdict,
  /// without a manual pull-to-refresh. The profile tab lives in an
  /// IndexedStack, so its initState fired at shell mount and won't refire on
  /// tab switch. Looked up via the service locator (not context) so it's
  /// safe before the first frame; ProfileCubit.fetch swallows its own errors.
  void _refreshStateForNotificationKind(String? kind) {
    if (!NotificationKind.fromString(kind).isSellerVerdict) return;
    if (!sl.isRegistered<ProfileCubit>()) return;
    unawaited(sl<ProfileCubit>().fetch());
  }

  /// Listens for incoming app/universal links. Sprint 11 mock: the simulator
  /// screen calls `DeepLinkService.handleUri(...)` and we route only when
  /// the target is customer-mode. Cross-mode links go through
  /// `NotificationHandler` (saved as a pending route) so the same machinery
  /// that handles push deep-links is reused.
  void _onDeepLink(DeepLinkTarget target) {
    if (!mounted) return;
    if (target.mode == AppMode.customer) {
      navigateCustomerRoute(_router, target.route);
    } else if (sl.isRegistered<NotificationHandler>()) {
      sl<NotificationHandler>().savePendingRoute(
        target.route,
        target.mode.name,
      );
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
          BlocProvider<UnpaidOrderCubit>.value(
            value: sl<UnpaidOrderCubit>(),
          ),
          BlocProvider<NetworkCubit>.value(value: sl<NetworkCubit>()),
          BlocProvider<ProfileOrdersCubit>.value(
            value: sl<ProfileOrdersCubit>(),
          ),
          BlocProvider<ProfileCubit>.value(value: sl<ProfileCubit>()),
          // Hoisted to the shell root so both the Profile-tab nav badge and
          // the in-profile "Suhbatlar" row read the same live unread count.
          BlocProvider<TotalUnreadChatsCubit>(
            create: (_) => TotalUnreadChatsCubit(
              sl<ChatRepository>(),
              ChatSenderRole.customer,
            ),
          ),
          // Same hoist for the support badge: the profile "Yordam" row reads
          // this live unread count; it seeds from the server and rides the
          // `support_message` WS frames + the read signal.
          BlocProvider<SupportUnreadCubit>(
            create: (_) => SupportUnreadCubit(sl<SupportChatRepository>()),
          ),
          // Root-scoped, shared with the home bell + inbox screens. Hoisted
          // here too so the profile's "Sotuvchi paneliga o'tish" badge can read
          // the live seller-surface unread count (state.sellerUnreadCount).
          BlocProvider<NotificationsCubit>.value(
            value: sl<NotificationsCubit>(),
          ),
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
            // AppUpdateGate is outermost so its force-update overlay paints
            // above the network banner and every route.
            child: AppUpdateGate(
              child: NetworkOverlayWrapper(
                // Reconciles an in-flight Payme/Click order payment on
                // return (resume poll + cold-start probe), so success is
                // shown only after the server confirms — never on placement.
                child: PaymentRecoveryGate(
                  onViewDetails: (_) {
                    final ctx = customerNavigatorKey.currentContext;
                    if (ctx != null) ctx.go('/orders');
                  },
                  onReconciled: (payment, outcome) {
                    if (outcome == PaymentOutcome.paid &&
                        payment.kind == PendingPaymentKind.order &&
                        sl.isRegistered<UnpaidOrderCubit>()) {
                      sl<UnpaidOrderCubit>().clearIfOrder(payment.reference);
                    }
                  },
                  child: child ?? const SizedBox.shrink(),
                ),
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
    required this.index,
    required super.child,
  });

  final void Function(int index) goToTab;

  /// The active tab index. Exposed so a tab-resident widget can tell whether
  /// it is the *visible* tab — the tabs live in an [IndexedStack], so a hidden
  /// tab's listeners keep firing, and e.g. a blocking network-error modal must
  /// not pop over a different tab. Reading this in `build` makes the reader
  /// rebuild when the tab changes.
  final int index;

  static CustomerShellScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<CustomerShellScope>();
    assert(scope != null, 'CustomerShellScope ancestor missing');
    return scope!;
  }

  @override
  bool updateShouldNotify(CustomerShellScope oldWidget) =>
      oldWidget.goToTab != goToTab || oldWidget.index != index;
}

/// Bottom-tab shell. All five tabs are mounted in an [IndexedStack] so each
/// keeps its scroll/listener state when the user switches tabs and comes
/// back — flipping Home → Favorites → Home no longer resets the home feed
/// to the top.
class CustomerHomeShell extends StatefulWidget {
  const CustomerHomeShell({super.key, this.initialTab});

  /// Deep-linked tab index (`/?tab=profile` → 4). Null = keep the current
  /// tab. Re-applied in [State.didUpdateWidget] so navigating to the query
  /// URL while the shell is already mounted still switches the tab.
  final int? initialTab;

  @override
  State<CustomerHomeShell> createState() => _CustomerHomeShellState();
}

class _CustomerHomeShellState extends State<CustomerHomeShell> {
  late int _index = widget.initialTab ?? 0;

  /// Stable English tab names for the nav log — independent of the active UI
  /// language so the console stream reads consistently while debugging.
  static const _tabNames = ['Home', 'Catalog', 'Cart', 'Favorites', 'Profile'];

  /// Timestamp of the last back press while the Home tab was active. Drives
  /// the double-back-to-exit gesture; reset whenever the tab changes so the
  /// two presses must be consecutive on Home.
  DateTime? _lastBackPress;

  /// Mounts after splash + tutorial gate. Wait one second so the home feed
  /// renders first, then surface the OS notification permission prompt —
  /// asking earlier (splash / onboarding) lowers opt-in rates significantly.
  static const _permissionPromptDelay = Duration(seconds: 1);

  /// ATT / Meta init lands a beat after the push prompt so the two iOS system
  /// dialogs queue in order instead of stacking on the freshly-rendered feed.
  static const _attPromptDelay = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    // A cold deep-link can mount the shell straight onto a tab
    // (`/?tab=profile` from a notification tap). Strip that one-shot query so
    // the URL doesn't keep pinning the tab — see [_consumeTabQuery].
    if (widget.initialTab != null) _consumeTabQuery();
    if (sl.isRegistered<PushService>() && !kScreenshotMode) {
      Future<void>.delayed(_permissionPromptDelay, () {
        if (!mounted) return;
        // Honour a prior Settings opt-out so a cold permission grant does not
        // re-subscribe the device to the marketing `news` topic.
        var enableNews = true;
        if (sl.isRegistered<Box>(instanceName: HiveBoxes.settings)) {
          final stored = sl<Box>(
            instanceName: HiveBoxes.settings,
          ).get(kPromoPushEnabledKey);
          if (stored is bool) enableNews = stored;
        }
        sl<PushService>().requestPermissionAndSubscribe(
          enableNewsTopic: enableNews,
        );
      });
    }
    // Bring Meta (Facebook) App Events online once the home feed is up. On iOS
    // this surfaces the App Tracking Transparency prompt and gates ALL Meta
    // tracking on the user's choice; on Android it initialises immediately.
    // Deferred past the splash (and after the push prompt) so the system
    // dialogs never stack on the brand splash. initialize() is idempotent and
    // non-throwing, so a remount / mode switch can't double-prompt or crash.
    if (sl.isRegistered<FacebookAnalyticsService>() && !kScreenshotMode) {
      Future<void>.delayed(_attPromptDelay, () {
        if (!mounted) return;
        unawaited(sl<FacebookAnalyticsService>().initialize());
      });
    }
  }

  @override
  void didUpdateWidget(CustomerHomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final requested = widget.initialTab;
    if (requested == null) return;
    if (requested != _index) _goToTab(requested);
    _consumeTabQuery();
  }

  /// `/?tab=` is a one-shot deep-link command, not durable state: the active
  /// tab lives in [_index], which a nav-bar tap flips via `setState` WITHOUT
  /// touching the URL. If we leave the query in the location, the next
  /// unrelated rebuild of the `/` route — e.g. pushing `/support` on top of the
  /// shell re-runs its builder — re-reads that now-stale `?tab=` and stomps the
  /// user's current tab back to it, stranding them on the wrong tab after Back.
  /// So once the requested tab is applied we drop the query, leaving `/`.
  void _consumeTabQuery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Never navigate out from under a route the user pushed on top of us.
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      context.go('/');
    });
  }

  void _goToTab(int i) {
    if (i == _index) return;
    _lastBackPress = null;
    AppNavigationLogger.logTabSwitch(i, _tabNames[i]);
    setState(() => _index = i);
  }

  /// System-back handler for the tab shell (Android). A non-Home tab returns
  /// to Home; on Home, the first press shows a hint and the second within
  /// 2 seconds exits the app — the conventional Android bottom-nav pattern.
  void _handleSystemBack() {
    if (_index != 0) {
      _goToTab(0);
      return;
    }
    final now = DateTime.now();
    final last = _lastBackPress;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Ilovadan chiqish uchun yana bir marta orqaga bosing'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      index: _index,
      child: PopScope(
        // The shell is the root route — never let the framework pop it
        // straight to an app exit; `_handleSystemBack` decides what happens.
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleSystemBack();
        },
        child: Scaffold(
          // The bottom nav is now flush (not floating), so the body lays out
          // directly above it — no extendBody.
          // Every premium tab renders its own header — suppress the shell AppBar
          // to avoid double titles.
          appBar:
              (_index == 0 ||
                  _index == 1 ||
                  _index == 2 ||
                  _index == 3 ||
                  _index == 4)
              ? null
              : AppBar(
                  title: Text(_titleForTab(_index)),
                  actions: const [_NotificationsAppBarAction()],
                ),
          // The connectivity banner is mounted globally by NetworkOverlayWrapper
          // in MaterialApp.builder, so it survives route changes and we don't
          // need a per-shell Column wrapper here.
          body: IndexedStack(index: _index, children: tabs),
          bottomNavigationBar: GlassBottomNav(
            currentIndex: _index,
            onTap: _goToTab,
            items: [
              GlassNavItem(
                label: tr('nav.home'),
                iconBuilder: (_, active) => _NavIcon(
                  icon: active ? Iconsax.home_2 : Iconsax.home_2_copy,
                  isActive: active,
                ),
              ),
              GlassNavItem(
                label: tr('nav.catalog'),
                iconBuilder: (_, active) => _NavIcon(
                  icon: active ? Iconsax.element_3 : Iconsax.element_3_copy,
                  isActive: active,
                ),
              ),
              GlassNavItem(
                label: tr('nav.cart'),
                iconBuilder: (_, active) => BlocBuilder<CartBloc, CartState>(
                  buildWhen: (a, b) => a.totalUnits != b.totalUnits,
                  builder: (context, state) {
                    final units = state.totalUnits;
                    final icon = _NavIcon(
                      icon: active
                          ? Iconsax.shopping_bag
                          : Iconsax.shopping_bag_copy,
                      isActive: active,
                    );
                    if (units == 0) return icon;
                    return Badge.count(count: units, child: icon);
                  },
                ),
              ),
              GlassNavItem(
                label: tr('nav.favorites'),
                iconBuilder: (_, active) => _NavIcon(
                  icon: active ? Iconsax.heart : Iconsax.heart_copy,
                  isActive: active,
                ),
              ),
              GlassNavItem(
                label: tr('nav.profile'),
                iconBuilder: (context, active) {
                  final icon = _NavIcon(
                    icon: active
                        ? Iconsax.profile_circle
                        : Iconsax.profile_circle_copy,
                    isActive: active,
                  );
                  return BlocBuilder<TotalUnreadChatsCubit, int>(
                    builder: (context, unread) => unread > 0
                        ? Badge.count(count: unread, child: icon)
                        : icon,
                  );
                },
              ),
            ],
          ),
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
      size: 24,
      color: isActive ? PremiumTokens.accent : PremiumTokens.of(context).grey,
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
      stream: sl<NotificationsRepository>().watchUnread(
        mode: AppMode.customer.name,
      ),
      initialData: sl<NotificationsRepository>().unreadCount(
        mode: AppMode.customer.name,
      ),
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
