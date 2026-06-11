import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/i18n/app_locale_controller.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/i18n/language_picker.dart';

const _delegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  setUp(() {
    // tr() reads the singleton bundle; seed it so the sheet's labels resolve.
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
  });

  testWidgets(
    'language picker lists native names and switches the locale on tap',
    (tester) async {
      final controller = AppLocaleController.inMemory(
        initial: const Locale('uz'),
      );
      registerAppLocaleControllerResolver(() => controller);
      addTearDown(() => registerAppLocaleControllerResolver(() => null));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('uz'),
          localizationsDelegates: _delegates,
          supportedLocales: AppTranslations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showLanguagePicker(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Native names render regardless of the active UI language.
      expect(find.text("O'zbekcha"), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      await tester.tap(find.text('Русский'));
      await tester.pumpAndSettle();

      // Choice is written through the controller (which persists + rebuilds
      // the app) and the sheet is dismissed.
      expect(controller.value, const Locale('ru'));
      expect(find.text('Русский'), findsNothing);
    },
  );

  testWidgets('the active language is marked with a check', (tester) async {
    final controller = AppLocaleController.inMemory(
      initial: const Locale('ru'),
    );
    registerAppLocaleControllerResolver(() => controller);
    addTearDown(() => registerAppLocaleControllerResolver(() => null));
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('ru')));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: _delegates,
        supportedLocales: AppTranslations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showLanguagePicker(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
