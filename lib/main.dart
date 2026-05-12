import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'config/app_mode.dart';
import 'core/auth/auth_cubit.dart';
import 'core/di/service_locator.dart';
import 'core/i18n/i18n.dart';
import 'core/logging/talker.dart';
import 'core/notifications/push_service.dart';
import 'customer/features/notifications/cubit/notifications_cubit.dart';
import 'core/storage/hive_boxes.dart';
import 'core/theme/theme_cubit.dart';
import 'core/widgets/app_splash_screen.dart';
import 'customer/customer_app.dart';
import 'firebase_options.dart';
import 'seller/seller_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The default Flutter overlay style on iOS leaves the status bar with
  // light icons, which become invisible on the app's light splash and
  // background. Set a dark-icon default at boot; per-theme appBarTheme
  // and the AnnotatedRegion in CustomerApp/SellerApp take over once the
  // MaterialApp mounts and react to theme changes.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  talker.info('App boot started');

  // Boot Firebase before the DI scope so PushService can be registered with
  // a live FirebaseMessaging.instance. The background handler must be
  // registered *before* the first await on FCM, hence its placement here.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e, st) {
    talker.handle(e, st, 'Firebase init failed — push disabled this run');
  }

  await initRootScope();

  final initialMode = getInitialMode();
  await initModeScope(initialMode);

  // Wire the foreground push listener at boot, but defer the OS permission
  // prompt until the user reaches the customer home shell (see
  // `_CustomerHomeShellState.initState`). Asking on splash / onboarding
  // tanks opt-in rates and feels intrusive.
  await sl<PushService>().bootstrap();
  _wireAuthToPushTokens();
  _wirePushToInboxRefresh();

  // Boot the locale controller from the Hive `settings` box so the
  // `MaterialApp` rebuilds when the user switches language.
  final settingsBox = sl<Box>(instanceName: HiveBoxes.settings);
  final localeController = AppLocaleController.fromBox(settingsBox);
  // Seed the singleton so any `tr(...)` invoked before the first
  // `Localizations.load` (e.g. boot logging) resolves correctly.
  AppTranslations.setInstance(
    AppTranslations.forLocale(localeController.value),
  );

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
        BlocProvider<AuthCubit>.value(value: sl<AuthCubit>()),
      ],
      child: _AppRoot(localeController: localeController),
    ),
  );
}

/// Tells [PushService] how to nudge the inbox when a foreground push lands.
/// Resolution is lazy — the [NotificationsCubit] is customer-scoped and
/// not yet registered at app boot, so we look it up at fire time and
/// silently skip if the user is currently in seller mode (where the
/// customer cubit isn't installed).
void _wirePushToInboxRefresh() {
  sl<PushService>().onForegroundPush = (_) {
    if (sl.isRegistered<NotificationsCubit>()) {
      sl<NotificationsCubit>().load();
    }
  };
}

/// Subscribes to the global [AuthCubit] so that:
///   * a successful sign-in (or a restored session at cold start) saves the
///     current FCM token under the user's id, and
///   * a sign-out tear-down is handled separately by `performLogout`, which
///     calls `removeCurrentToken()` *before* clearing the Supabase session
///     (RLS would deny the delete after sign-out).
///
/// Listener fires once per state change after registration; we also push
/// the current state through it manually so a session restored synchronously
/// in `AuthCubit._init` (before this subscription was attached) still
/// triggers a token sync.
void _wireAuthToPushTokens() {
  final authCubit = sl<AuthCubit>();
  final pushService = sl<PushService>();

  void handleState(AppAuthState state) {
    if (state is AppAuthAuthenticated) {
      pushService.syncTokenForUser(state.userId);
    }
  }

  handleState(authCubit.state);
  authCubit.stream.listen(handleState);
}

class _AppRoot extends StatelessWidget {
  const _AppRoot({required this.localeController});

  final AppLocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return Phoenix(
      child: _LocaleScope(
        controller: localeController,
        // _ModeRouter sits *ins55ide* Phoenix on purpose. Phoenix.rebirth
        // changes the subtree key, which forces _ModeRouter to be built
        // afresh — its build() re-reads `getInitialMode()` from Hive so
        // the post-rebirth tree picks up the new app_mode written by
        // `switchAppMode`. Capturing the mode in `_App1Root` (above Phoenix)
        // would freeze it at startup and ignore mode flips.
        child: const _ModeRouter(),
      ),
    );
  }
}

/// Holds the splash for a minimum dwell time on cold start, then crossfades
/// into the active mode app. Without this, on a fast device the brand splash
/// would barely register — the heavy init in `main()` is already done by the
/// time we get here, so we deliberately gate the transition on a timer.
///
/// Phoenix.rebirth (mode switch) recreates this widget with a new key, so
/// the splash also briefly shows on customer↔seller flips, masking any
/// flicker from the DI scope swap. If you want instantaneous mode switches
/// instead, lower [_minSplashDuration] or branch on a `coldStart` flag.
class _ModeRouter extends StatefulWidget {
  const _ModeRouter();

  @override
  State<_ModeRouter> createState() => _ModeRouterState();
}

class _ModeRouterState extends State<_ModeRouter> {
  static const _minSplashDuration = Duration(milliseconds: 1400);
  static const _crossfadeDuration = Duration(milliseconds: 360);

  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_minSplashDuration, () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = switch (getInitialMode()) {
      AppMode.customer => const CustomerApp(),
      AppMode.seller => const SellerApp(),
    };
    // We sit above MaterialApp, so Directionality / DefaultTextStyle aren't
    // provided yet. AnimatedSwitcher's Stack and the splash's Text widgets
    // both need a TextDirection — explicit LTR keeps them rendering during
    // the crossfade window (the inner MaterialApp takes over once `app`
    // mounts, so this wrapper is only consulted during splash).
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedSwitcher(
        duration: _crossfadeDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _splashDone
            ? KeyedSubtree(key: const ValueKey('app'), child: app)
            : const KeyedSubtree(
                key: ValueKey('splash'),
                child: AppSplashScreen(),
              ),
      ),
    );
  }
}

class _LocaleScope extends StatefulWidget {
  const _LocaleScope({required this.controller, required this.child});

  final AppLocaleController controller;
  final Widget child;

  @override
  State<_LocaleScope> createState() => _LocaleScopeState();
}

class _LocaleScopeState extends State<_LocaleScope> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onLocaleChanged);
    // Expose the controller via the resolver in i18n.dart so widgets
    // like the language picker can find it without a DI lookup.
    registerAppLocaleControllerResolver(() => widget.controller);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (!mounted) return;
    AppTranslations.setInstance(
      AppTranslations.forLocale(widget.controller.value),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppLocaleScope(
      controller: widget.controller,
      child: widget.child,
    );
  }
}

/// `InheritedWidget` so child widgets can read the active locale controller
/// (e.g. a language picker dropdown writes the new locale through it).
class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  const AppLocaleScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocaleController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope != null, 'AppLocaleScope ancestor missing');
    return scope!.notifier!;
  }
}
