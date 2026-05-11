import 'package:flutter/widgets.dart';

import 'app_translations.dart';

/// Hooks our pure-Dart translation bundles into Flutter's standard
/// `Localizations` machinery. `MaterialApp` wires it up via
/// `localizationsDelegates`. On every locale switch it rebuilds the
/// in-memory [AppTranslations] singleton so the top-level `tr(...)`
/// function picks up the new bundle.
class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppTranslations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppTranslations.supportedLocales
      .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppTranslations> load(Locale locale) async {
    final translations = AppTranslations.forLocale(locale);
    AppTranslations.setInstance(translations);
    return translations;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppTranslations> old) =>
      false;
}
