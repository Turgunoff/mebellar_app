import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'config/app_config.dart';
import 'config/app_mode.dart';
import 'config/remote_config.dart';
import 'core/auth/app_mode_cubit.dart';
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
import 'core/i18n/translations/_missing_keys_check.dart';
import 'firebase_options.dart';
import 'seller/seller_app.dart';

Future<void> main() async {
  // Sentry's binding (a WidgetsFlutterBinding subclass) must be the one that
  // gets instantiated first, otherwise FramesTrackingIntegration disables
  // itself ("incompatible binding"). It powers Sentry's UI frame-drop / jank
  // tracking, so install it here in place of the plain binding.
  SentryWidgetsFlutterBinding.ensureInitialized();

  // Fail fast: a build launched with no env file has empty Supabase / Yandex
  // credentials — abort here, loudly, rather than silently running blank.
  AppConfig.assertConfigured();

  // ROADMAP B.8 — debug-only guard: throws the instant the ru/en bundles
  // drift below the uz baseline, so a missing translation is caught at boot
  // instead of shipping a raw `key.path` to users. No-op in release builds.
  assertTranslationsComplete();

  // Sentry wraps the whole app in an error-capturing zone. An empty
  // SENTRY_DSN leaves the SDK initialised-but-disabled; Talker errors are
  // additionally forwarded to Sentry via SentryTalkerObserver.
  await SentryFlutter.init(
    (options) {
      options.dsn = AppConfig.sentryDsn;
      options.environment = AppConfig.environment;
      options.tracesSampleRate = AppConfig.isProd ? 0.2 : 1.0;
      // Sentry's own diagnostic logging follows the build mode, not the
      // environment: a debug build (even on the prod env) prints transport
      // logs to the console so issues are visible locally; release builds
      // stay quiet.
      options.debug = kDebugMode;
    },
    appRunner: _bootstrapAndRun,
  );
}

/// Boots every subsystem and mounts the widget tree. Runs inside the Sentry
/// zone (via `SentryFlutter.init`'s `appRunner`) so uncaught errors during
/// startup are still captured.
Future<void> _bootstrapAndRun() async {
  // Force the system bars back on at every boot. The Flutter engine remembers
  // the last `setEnabledSystemUIMode` call across hot restart and full
  // process restarts on some platforms — if a screen ever entered
  // `immersiveSticky` (e.g. the fullscreen image viewer) and didn't restore
  // cleanly, the app would launch with the status bar still hidden until the
  // user power-cycled the device. Resetting to `manual` with the full
  // overlay list here makes boot deterministic.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

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

  // Hydrate runtime feature flags. The cached value paints instantly; the
  // network refresh updates it for screens shown after the splash and for the
  // next launch. Not awaited — boot must never block on the network.
  RemoteConfig.instance.hydrateFromCache(settingsBox);
  unawaited(RemoteConfig.instance.refresh(sl<SupabaseClient>(), settingsBox));

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
        // AppModeCubit sits above Phoenix so customer↔seller surfaces can read
        // the active mode without going through `getInitialMode()` and so a
        // `switchMode(...)` from anywhere triggers the listener that owns the
        // scope swap + Phoenix.rebirth (wired inside `_AppRoot`).
        BlocProvider<AppModeCubit>.value(value: sl<AppModeCubit>()),
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
      // The mode-swap listener sits *inside* Phoenix so it has a context that
      // Phoenix can rebirth. When AppModeCubit emits a new mode (e.g. from a
      // button calling `cubit.switchMode(...)` or from the security guard
      // demoting an unapproved seller), this listener invokes the same
      // scope-swap + Phoenix.rebirth flow `switchAppMode(...)` already runs.
      //
      // It skips when `getInitialMode()` already matches the new mode —
      // that's the case where `switchAppMode(...)` was the caller and the
      // scope swap has already happened by the time the cubit's emit landed.
      child: BlocListener<AppModeCubit, AppMode>(
        listenWhen: (prev, next) => prev != next,
        listener: (context, mode) async {
          // The boot scope already matches the boot-resolved mode; skip if
          // the active GetIt scope is already what the cubit just emitted.
          // This handles redundant emits without double-disposing services.
          if (sl.currentScopeName == mode.name) return;
          await sl.popScope();
          await initModeScope(mode);
          if (context.mounted) Phoenix.rebirth(context);
        },
        child: _LocaleScope(
          controller: localeController,
          // _ModeRouter sits inside Phoenix on purpose. Phoenix.rebirth
          // changes the subtree key, which forces _ModeRouter to be built
          // afresh — its build() re-reads `getInitialMode()` so the
          // post-rebirth tree picks up the new app_mode written by the
          // cubit. Capturing the mode in `_AppRoot` (above Phoenix) would
          // freeze it at startup and ignore mode flips.
          child: const _ModeRouter(),
        ),
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