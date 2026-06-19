import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/storage/app_settings.dart';
import 'package:woody_app/core/theme/app_colors.dart';
import 'package:woody_app/core/theme/theme_cubit.dart';
import 'package:woody_app/core/widgets/app_splash_screen.dart';

class _MockSettings extends Mock implements AppSettings {}

/// The splash sits above MaterialApp, so it can't read `Theme.of`. It resolves
/// brightness from [ThemeCubit] instead — this guards that its background flips
/// with the persisted theme mode (regression for the light-only splash).
void main() {
  Future<Color> splashBackground(WidgetTester tester, ThemeMode mode) async {
    final settings = _MockSettings();
    when(() => settings.themeMode).thenReturn(mode);
    await tester.pumpWidget(
      BlocProvider<ThemeCubit>(
        create: (_) => ThemeCubit(settings),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: AppSplashScreen(),
        ),
      ),
    );
    // Single pump only — the entrance + spinner animations never settle.
    await tester.pump();
    return tester.widget<ColoredBox>(find.byType(ColoredBox).first).color;
  }

  testWidgets('light mode -> off-white background', (tester) async {
    expect(
      await splashBackground(tester, ThemeMode.light),
      AppColors.lightBackground,
    );
  });

  testWidgets('dark mode -> near-black background', (tester) async {
    expect(
      await splashBackground(tester, ThemeMode.dark),
      AppColors.darkBackground,
    );
  });
}
