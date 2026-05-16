import 'package:flutter/widgets.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'sentry_talker_observer.dart';

/// App-wide [Talker] instance. Pair with [TalkerRouteObserver] in
/// `MaterialApp.navigatorObservers` (or `GoRouter.observers`) so every
/// push/pop/replace also lands in the log.
///
/// `useConsoleLogs: false` silences the noisy ASCII boxes in the IDE
/// terminal. Logs are still kept in memory and visible in `TalkerScreen`
/// (opened via the debug bug FAB).
final Talker talker = TalkerFlutter.init(
  settings: TalkerSettings(
    useConsoleLogs: false,
  ),
  // Forwards every handled error/exception to Sentry. Safe to leave wired
  // even with an empty SENTRY_DSN — Sentry is then disabled and the
  // observer's `captureException` calls become no-ops.
  observer: SentryTalkerObserver(),
);

/// Navigator keys exposed at module scope so the debug Talker overlay can
/// push the log screen from within `MaterialApp.builder`, where the builder's
/// context sits *above* the Navigator and `Navigator.of(context)` would fail.
///
/// Two separate keys (rather than one shared key) because Phoenix.rebirth
/// can briefly mount the new app before the old one fully disposes; assigning
/// the same `GlobalKey` to two `Navigator`s in the same frame asserts.
final GlobalKey<NavigatorState> customerNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'customerNavigatorKey');
final GlobalKey<NavigatorState> sellerNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sellerNavigatorKey');
