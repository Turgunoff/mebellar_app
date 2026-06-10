import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/storage/app_settings.dart';
import 'package:woody_app/core/theme/theme_cubit.dart';

class _MockAppSettings extends Mock implements AppSettings {}

void main() {
  late _MockAppSettings settings;

  setUpAll(() => registerFallbackValue(ThemeMode.system));

  setUp(() {
    settings = _MockAppSettings();
    when(() => settings.themeMode).thenReturn(ThemeMode.system);
    when(() => settings.setThemeMode(any())).thenAnswer((_) async {});
  });

  test('initial state defaults to system when nothing is persisted', () {
    final cubit = ThemeCubit(settings);
    expect(cubit.state.themeMode, ThemeMode.system);
    cubit.close();
  });

  test('initial state reflects a persisted dark preference', () {
    when(() => settings.themeMode).thenReturn(ThemeMode.dark);
    final cubit = ThemeCubit(settings);
    expect(cubit.state.themeMode, ThemeMode.dark);
    cubit.close();
  });

  blocTest<ThemeCubit, ThemeState>(
    'toggleDark(true) emits dark mode and persists it',
    build: () => ThemeCubit(settings),
    act: (cubit) => cubit.toggleDark(true),
    expect: () => [
      isA<ThemeState>().having((s) => s.themeMode, 'mode', ThemeMode.dark),
    ],
    verify: (_) =>
        verify(() => settings.setThemeMode(ThemeMode.dark)).called(1),
  );

  blocTest<ThemeCubit, ThemeState>(
    'toggleDark(false) from a dark start emits light mode',
    build: () {
      when(() => settings.themeMode).thenReturn(ThemeMode.dark);
      return ThemeCubit(settings);
    },
    act: (cubit) => cubit.toggleDark(false),
    expect: () => [
      isA<ThemeState>().having((s) => s.themeMode, 'mode', ThemeMode.light),
    ],
    verify: (_) =>
        verify(() => settings.setThemeMode(ThemeMode.light)).called(1),
  );

  blocTest<ThemeCubit, ThemeState>(
    'setThemeMode no-ops (no emit, no write) when the mode is unchanged',
    build: () => ThemeCubit(settings), // starts at system
    act: (cubit) => cubit.setThemeMode(ThemeMode.system),
    expect: () => const <ThemeState>[],
    verify: (_) => verifyNever(() => settings.setThemeMode(any())),
  );
}
