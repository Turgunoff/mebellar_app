import 'package:hive/hive.dart';

/// Strongly-typed facade over the `settings` Hive box.
///
/// The raw box is read with magic strings scattered across the codebase
/// (`'app_mode'` in [AppModeCubit], `'isDarkMode'` in `ThemeCubit`,
/// `'seller_approval_cached'`, ...). A typo silently returns `null` and
/// degrades behaviour with no error. This wrapper makes every key private and
/// every accessor typed, so the compiler — not a QA pass — catches mistakes.
///
/// Register one instance in the root DI scope; cubits and services take an
/// [AppSettings] instead of a raw `Box`. Key strings below are kept BYTE-FOR-
/// BYTE identical to the legacy magic strings so existing persisted rows are
/// read without a migration.
class AppSettings {
  AppSettings(this._box);

  final Box _box;

  // --- key registry (private — no caller ever sees a raw string) -----------
  static const String _kAppMode = 'app_mode';
  static const String _kSellerApproved = 'seller_approval_cached';
  static const String _kDarkMode = 'isDarkMode';
  static const String _kLocaleCode = 'locale_code';
  static const String _kOnboardingSeen = 'onboarding_seen';

  // --- active app mode -----------------------------------------------------
  /// Persisted [AppMode] name, or `null` before the user has ever chosen one.
  /// Kept as a raw `String?` so this class need not depend on the `AppMode`
  /// enum — [AppModeCubit] owns the `name` <-> enum mapping.
  String? get appModeName => _box.get(_kAppMode) as String?;
  Future<void> setAppModeName(String name) => _box.put(_kAppMode, name);
  Future<void> clearAppMode() => _box.delete(_kAppMode);

  // --- cached seller approval flag ----------------------------------------
  /// Last-known seller approval state — drives the synchronous boot-time
  /// security guard in [AppModeCubit] before any network call is possible.
  bool get sellerApproved =>
      _box.get(_kSellerApproved, defaultValue: false) as bool;
  Future<void> setSellerApproved(bool value) =>
      _box.put(_kSellerApproved, value);
  Future<void> clearSellerApproved() => _box.delete(_kSellerApproved);

  // --- theme ---------------------------------------------------------------
  bool get isDarkMode => _box.get(_kDarkMode, defaultValue: false) as bool;
  Future<void> setDarkMode(bool value) => _box.put(_kDarkMode, value);

  // --- locale --------------------------------------------------------------
  /// Overridden locale code (`uz` / `ru` / `en`); `null` follows the device.
  String? get localeCode => _box.get(_kLocaleCode) as String?;
  Future<void> setLocaleCode(String code) => _box.put(_kLocaleCode, code);
  Future<void> clearLocaleCode() => _box.delete(_kLocaleCode);

  // --- onboarding ----------------------------------------------------------
  bool get onboardingSeen =>
      _box.get(_kOnboardingSeen, defaultValue: false) as bool;
  Future<void> setOnboardingSeen(bool value) =>
      _box.put(_kOnboardingSeen, value);

  /// Clears the per-user keys on sign-out (active mode + cached approval) so
  /// the next account on this device cannot inherit them. Device-level
  /// preferences (theme, locale, onboarding) are intentionally left intact.
  Future<void> clearUserScopedKeys() async {
    await clearAppMode();
    await clearSellerApproved();
  }
}
