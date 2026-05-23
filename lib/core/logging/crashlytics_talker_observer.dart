import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Bridges the app-wide [Talker] to Firebase Crashlytics: every error or
/// exception logged through `talker.handle(...)` is also recorded as a
/// non-fatal entry in the Crashlytics dashboard.
///
/// Installed on the [talker] singleton via `TalkerFlutter.init(observer:
/// ...)`. Skips when Firebase couldn't initialise (e.g. dev build without
/// `google-services.json`), so this observer is safe to leave wired in
/// every build, including local runs.
class CrashlyticsTalkerObserver extends TalkerObserver {
  @override
  void onError(TalkerError err) =>
      _capture(err.error, err.stackTrace, err.message);

  @override
  void onException(TalkerException err) =>
      _capture(err.exception, err.stackTrace, err.message);

  void _capture(Object? error, StackTrace? stackTrace, String? message) {
    // Defensive: Crashlytics throws if Firebase is not initialised. Talker
    // errors fired before `Firebase.initializeApp` (e.g. very early boot
    // failures) would otherwise crash the crash-reporter itself.
    if (Firebase.apps.isEmpty) return;
    FirebaseCrashlytics.instance.recordError(
      error ?? message ?? 'Unknown error reported via Talker',
      stackTrace,
      reason: message,
      // Non-fatal — these come from caught/handled errors. Fatal crashes
      // are wired separately in main.dart via FlutterError.onError and
      // PlatformDispatcher.onError.
      fatal: false,
    );
  }
}
