import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/storage/app_settings.dart';
import 'package:woody_app/core/theme/theme_cubit.dart';
import 'package:woody_app/core/theme/theme_mode_picker.dart';

class _MockAppSettings extends Mock implements AppSettings {}

const _delegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  late _MockAppSettings settings;

  setUpAll(() => registerFallbackValue(ThemeMode.system));

  setUp(() {
    // tr() reads the singleton bundle; seed it so the sheet's labels resolve.
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
    settings = _MockAppSettings();
    when(() => settings.setThemeMode(any())).thenAnswer((_) async {});
  });

  Future<ThemeCubit> pumpPicker(WidgetTester tester, ThemeMode initial) async {
    when(() => settings.themeMode).thenReturn(initial);
    final cubit = ThemeCubit(settings);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: _delegates,
        supportedLocales: AppTranslations.supportedLocales,
        home: BlocProvider<ThemeCubit>.value(
          value: cubit,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showThemeModePicker(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('lists all three theme options', (tester) async {
    await pumpPicker(tester, ThemeMode.system);

    expect(find.text('Tizimga mos'), findsOneWidget);
    expect(find.text("Yorug'"), findsOneWidget);
    expect(find.text("Qorong'i"), findsOneWidget);
  });

  testWidgets('marks the active mode with a check', (tester) async {
    await pumpPicker(tester, ThemeMode.dark);

    // Only the active tile (dark) carries the check.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets(
    'selecting a mode persists it through the cubit and dismisses the sheet',
    (tester) async {
      final cubit = await pumpPicker(tester, ThemeMode.system);

      await tester.tap(find.text("Yorug'"));
      await tester.pumpAndSettle();

      expect(cubit.state.themeMode, ThemeMode.light);
      verify(() => settings.setThemeMode(ThemeMode.light)).called(1);
      // Sheet dismissed.
      expect(find.text("Yorug'"), findsNothing);
    },
  );
}
