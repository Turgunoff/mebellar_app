import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Bridges the app-wide [Talker] to Sentry: every error or exception recorded
/// through `talker.handle(...)` is also forwarded to `Sentry.captureException`.
///
/// Installed on the [talker] singleton via `TalkerFlutter.init(observer: ...)`.
/// When `SENTRY_DSN` is empty the Sentry SDK initialises in a disabled state
/// and `captureException` is a no-op, so this observer is safe to leave wired
/// in every build, including local dev runs.
class SentryTalkerObserver extends TalkerObserver {
  @override
  void onError(TalkerError err) =>
      _capture(err.error, err.stackTrace, err.message);

  @override
  void onException(TalkerException err) =>
      _capture(err.exception, err.stackTrace, err.message);

  void _capture(Object? error, StackTrace? stackTrace, String? message) {
    Sentry.captureException(
      error ?? message ?? 'Unknown error reported via Talker',
      stackTrace: stackTrace,
    );
  }
}
