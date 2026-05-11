import 'package:flutter/widgets.dart';

import 'translations/all_translations.dart';

/// Holds the translation bundle for the active locale and exposes the
/// `tr(key)` lookup helper. The legacy easy_localization API kept a global
/// singleton — we mirror that with [AppTranslations.instance] so existing
/// `tr('foo.bar')` call sites resolve without needing a `BuildContext`.
class AppTranslations {
  AppTranslations(this.locale, this._bundle);

  final Locale locale;
  final Map<String, dynamic> _bundle;

  /// Cached singleton kept in sync with the active locale by the
  /// [AppLocalizationsDelegate]. Falls back to Uzbek if accessed before
  /// any delegate has loaded — important for early boot logs.
  static AppTranslations _instance =
      AppTranslations(const Locale('uz'), uzTranslations);

  static AppTranslations get instance => _instance;

  static const supportedLocales = <Locale>[
    Locale('uz'),
    Locale('ru'),
    Locale('en'),
  ];

  static const fallbackLocale = Locale('uz');

  /// Build the in-memory bundle for [locale]. Unknown languages fall back
  /// to Uzbek rather than throwing — avoids a crash if a future locale
  /// sneaks in via system settings before we add a Dart bundle for it.
  static AppTranslations forLocale(Locale locale) {
    final bundle = _bundleFor(locale.languageCode);
    return AppTranslations(locale, bundle);
  }

  static Map<String, dynamic> _bundleFor(String code) {
    return switch (code) {
      'ru' => ruTranslations,
      'en' => enTranslations,
      _ => uzTranslations,
    };
  }

  /// Set by [AppLocalizationsDelegate.load] so the top-level `tr(...)`
  /// function and `instance` accessor see the freshest bundle without a
  /// `BuildContext`.
  static void setInstance(AppTranslations next) {
    _instance = next;
  }

  /// Look up [key] (dot-separated path: e.g. `cart.empty`) and substitute
  /// `{}` placeholders with [args] in order, then `{name}` placeholders
  /// from [namedArgs]. When the key is missing, returns the key itself —
  /// matches the legacy easy_localization fallback semantics.
  String tr(
    String key, {
    List<Object>? args,
    Map<String, String>? namedArgs,
  }) {
    final value = _resolve(key);
    if (value is! String) return key;
    return _format(value, args, namedArgs);
  }

  Object? _resolve(String key) {
    final parts = key.split('.');
    Object? cursor = _bundle;
    for (final p in parts) {
      if (cursor is Map) {
        cursor = cursor[p];
      } else {
        return null;
      }
    }
    return cursor;
  }

  String _format(
    String template,
    List<Object>? args,
    Map<String, String>? namedArgs,
  ) {
    var out = template;
    if (args != null && args.isNotEmpty) {
      var i = 0;
      out = out.replaceAllMapped(RegExp(r'\{\}'), (_) {
        if (i >= args.length) return '';
        return args[i++].toString();
      });
    }
    if (namedArgs != null && namedArgs.isNotEmpty) {
      namedArgs.forEach((k, v) {
        out = out.replaceAll('{$k}', v);
      });
    }
    return out;
  }
}
