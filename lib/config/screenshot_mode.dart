/// Marketing-screenshot mode, enabled with `--dart-define=SCREENSHOT_MODE=true`
/// (see `integration_test/screenshot_generator_test.dart`). Debug-only UI that
/// would dirty a store/landing screenshot is hidden behind this flag:
///   * the draggable Talker bug FAB (`DebugTalkerOverlay`), and
///   * the customer home shell's OS push-permission prompt — an iOS system
///     dialog would otherwise paint over the first captured frame.
/// Defaults to false, so normal debug runs are unaffected.
const bool kScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');
