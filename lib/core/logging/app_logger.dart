import 'dart:async';
import 'dart:io' show SocketException;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../network/api_error.dart';

/// App-wide lightweight logger.
///
/// Replaces the former `talker_flutter`-backed logger: handled
/// errors/exceptions are forwarded to Firebase Crashlytics as non-fatal entries
/// (the bridge the old `TalkerObserver` provided), and info/warning/error lines
/// print to the debug console only. No in-app log screen, no extra dependency.
///
/// The method surface (`handle` / `info` / `warning` / `error`) mirrors the old
/// `talker` singleton so call sites stay unchanged apart from the name.
class AppLogger {
  const AppLogger();

  /// Record a caught error/exception. In debug it prints; in every build it is
  /// forwarded to Crashlytics as a non-fatal entry. `msg` is an optional
  /// human-readable reason. Mirrors the old logger's `handle(...)`.
  void handle(Object error, [StackTrace? stackTrace, Object? msg]) {
    if (kDebugMode) {
      debugPrint('[ERROR]${msg == null ? '' : ' $msg'} — $error');
      if (stackTrace != null) debugPrint('$stackTrace');
    }
    _record(error, stackTrace, msg?.toString());
  }

  void info(Object? msg, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[INFO] $msg${error == null ? '' : ' — $error'}');
      if (stackTrace != null) debugPrint('$stackTrace');
    }
  }

  void warning(Object? msg, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[WARN] $msg${error == null ? '' : ' — $error'}');
      if (stackTrace != null) debugPrint('$stackTrace');
    }
  }

  /// Log an error line. With an attached [error] object it is also recorded to
  /// Crashlytics (non-fatal); a bare message is debug-console only.
  void error(Object? msg, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $msg${error == null ? '' : ' — $error'}');
      if (stackTrace != null) debugPrint('$stackTrace');
    }
    if (error != null) _record(error, stackTrace, msg?.toString());
  }

  void _record(Object error, StackTrace? stackTrace, String? reason) {
    // Crashlytics throws if Firebase failed to initialise (a dev build without
    // google-services, or a very-early-boot failure) — skip rather than crash
    // the crash-reporter itself.
    if (Firebase.apps.isEmpty) return;
    // Drop expected, non-actionable conditions before they reach the dashboard:
    // a dropped connection / timeout is the user's network, and a 401 is an
    // expired session the global 401 interceptor already turns into a forced
    // sign-out. Reporting these as non-fatals only buries real defects under
    // recurring noise — they still print to the debug console above.
    if (_isExpectedTransient(error)) return;
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
      // Non-fatal — these come from caught/handled errors. Fatal crashes are
      // wired separately in main.dart via FlutterError.onError and
      // PlatformDispatcher.onError.
      fatal: false,
    );
  }

  /// Connectivity blips and expired-session errors are routine on mobile and
  /// never point at a code defect, so they must not land in Crashlytics.
  static bool _isExpectedTransient(Object error) {
    if (error is ApiError) {
      // status 0 / `network_error` = no HTTP response at all (failed host
      // lookup, connection or read timeout — see WoodyApiClient._toApiError).
      // 401 = dead session, handled by the 401 interceptor + forced logout.
      return error.status == 0 ||
          error.code == 'network_error' ||
          error.isUnauthorized;
    }
    // Raw connectivity errors thrown before reaching the Woody client layer.
    return error is SocketException || error is TimeoutException;
  }
}

/// App-wide logger instance. (Formerly the `talker` singleton.)
final AppLogger appLog = const AppLogger();

/// Navigator keys exposed at module scope so push/notification handlers can
/// navigate from outside the widget tree.
///
/// Two separate keys (rather than one shared key) because `Phoenix.rebirth`
/// can briefly mount the new app before the old one fully disposes; assigning
/// the same `GlobalKey` to two `Navigator`s in the same frame asserts.
final GlobalKey<NavigatorState> customerNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'customerNavigatorKey');
final GlobalKey<NavigatorState> sellerNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'sellerNavigatorKey',
);
