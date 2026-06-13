import 'package:flutter/material.dart' show ThemeMode;
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
  static const String _kThemeMode = 'theme_mode';
  static const String _kLocaleCode = 'locale_code';
  static const String _kOnboardingSeen = 'onboarding_seen';
  static const String _kSellerWelcomePrefix = 'has_seen_seller_welcome_';
  static const String _kProductViewMode = 'product_view_mode';

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

  /// The user's global theme preference, shared by the customer and seller
  /// surfaces. Defaults to [ThemeMode.system] when never chosen, so a fresh
  /// install follows the device setting. Upgrading users who toggled the
  /// legacy `isDarkMode` bool are migrated to the matching explicit mode.
  ///
  /// A device-level preference: intentionally NOT cleared on logout
  /// ([clearUserScopedKeys]).
  ThemeMode get themeMode {
    switch (_box.get(_kThemeMode) as String?) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
    }
    // No explicit choice yet — honour the legacy bool only when it was set
    // to true; anything else (including unset) follows the system default.
    return (_box.get(_kDarkMode) as bool?) == true
        ? ThemeMode.dark
        : ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _box.put(_kThemeMode, mode.name);
    // Keep the legacy mirror coherent for any older code path still reading it.
    await _box.put(_kDarkMode, mode == ThemeMode.dark);
  }

  // --- locale --------------------------------------------------------------
  /// Overridden locale code (`uz` / `ru` / `en`); `null` follows the device.
  String? get localeCode => _box.get(_kLocaleCode) as String?;
  Future<void> setLocaleCode(String code) => _box.put(_kLocaleCode, code);
  Future<void> clearLocaleCode() => _box.delete(_kLocaleCode);

  // --- product feed view mode ----------------------------------------------
  /// Persisted grid/list toggle for the home feed and per-category product
  /// lists, shared so the choice applies everywhere the catalogue is browsed.
  /// Kept as a raw `String?` (the `ProductViewMode.name`) so this class need
  /// not depend on the customer-layer enum — mirrors [appModeName]. `null`
  /// before the user has ever toggled; callers default to grid.
  ///
  /// A device-level presentation preference: intentionally NOT cleared on
  /// logout ([clearUserScopedKeys]).
  String? get productViewModeName => _box.get(_kProductViewMode) as String?;
  Future<void> setProductViewModeName(String name) =>
      _box.put(_kProductViewMode, name);

  // --- onboarding ----------------------------------------------------------
  bool get onboardingSeen =>
      _box.get(_kOnboardingSeen, defaultValue: false) as bool;
  Future<void> setOnboardingSeen(bool value) =>
      _box.put(_kOnboardingSeen, value);

  // --- one-time seller welcome screen --------------------------------------
  /// Whether the approved seller [sellerId] has already seen the celebratory
  /// welcome screen. Keyed per seller so the flag survives logout (re-login
  /// must not replay it) and never bleeds across accounts on a shared device —
  /// which is also why it's intentionally NOT cleared in
  /// [clearUserScopedKeys].
  bool hasSeenSellerWelcome(String sellerId) =>
      _box.get('$_kSellerWelcomePrefix$sellerId', defaultValue: false) as bool;
  Future<void> setSellerWelcomeSeen(String sellerId) =>
      _box.put('$_kSellerWelcomePrefix$sellerId', true);

  /// Clears the per-user keys on sign-out (active mode + cached approval) so
  /// the next account on this device cannot inherit them. Device-level
  /// preferences (theme, locale, onboarding) are intentionally left intact.
  Future<void> clearUserScopedKeys() async {
    await clearAppMode();
    await clearSellerApproved();
  }
}
