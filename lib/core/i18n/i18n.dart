import 'package:flutter/widgets.dart';

import 'app_translations.dart';

/// Single import surface that mirrors the legacy easy_localization API:
///
///   * Top-level `tr('key.subkey', args: [...], namedArgs: {...})`
///   * `context.locale` extension for the active locale
///   * `context.localizationDelegates` and `context.supportedLocales` for
///     `MaterialApp` setup
///   * Re-exports `NumberFormat` and `DateFormat` from `package:intl` so
///     widgets that used those via easy_localization keep working without
///     adding direct intl imports.
///
/// The migration goal is `s/import 'package:easy_localization/...'/import
/// 'core/i18n/i18n.dart'/` with no other call-site changes.
export 'package:intl/intl.dart' show NumberFormat, DateFormat;

export 'app_locale_controller.dart';
export 'app_translations.dart';
export 'app_translations_delegate.dart';

/// Translate [key]. Mirrors `easy_localization`'s top-level `tr()` so
/// existing call sites resolve unchanged. Honours the singleton bundle the
/// `AppLocalizationsDelegate.load` writes on every locale switch.
String tr(
  String key, {
  List<Object>? args,
  Map<String, String>? namedArgs,
}) =>
    AppTranslations.instance.tr(key, args: args, namedArgs: namedArgs);

/// Convenience extensions covering the `context.locale.languageCode` /
/// `context.localizationDelegates` / `context.supportedLocales` patterns
/// the codebase already uses.
extension AppLocalizationsContext on BuildContext {
  /// The active locale resolved by `Localizations`. Falls back to the
  /// platform locale when the `Localizations` ancestor isn't ready yet
  /// (e.g. during the very first build before `MaterialApp.locale`
  /// propagates).
  Locale get locale =>
      Localizations.maybeLocaleOf(this) ?? AppTranslations.instance.locale;

  /// Drop-in replacement for `easy_localization`'s `context.tr`.
  String tr(
    String key, {
    List<Object>? args,
    Map<String, String>? namedArgs,
  }) =>
      AppTranslations.instance.tr(key, args: args, namedArgs: namedArgs);
}
