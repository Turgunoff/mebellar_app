import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/theme/theme_cubit.dart';

class _MockBox extends Mock implements Box {}

void main() {
  late _MockBox box;

  setUp(() {
    box = _MockBox();
    when(() => box.get('isDarkMode', defaultValue: false)).thenReturn(false);
    when(() => box.put(any<dynamic>(), any<dynamic>()))
        .thenAnswer((_) async {});
  });

  test('initial state is light when nothing is persisted', () {
    final cubit = ThemeCubit(box);
    expect(cubit.state.themeMode, ThemeMode.light);
    expect(cubit.isDark, isFalse);
    cubit.close();
  });

  test('initial state is dark when the box has a stored true flag', () {
    when(() => box.get('isDarkMode', defaultValue: false)).thenReturn(true);
    final cubit = ThemeCubit(box);
    expect(cubit.state.themeMode, ThemeMode.dark);
    cubit.close();
  });

  blocTest<ThemeCubit, ThemeState>(
    'setDark(true) emits dark mode and persists the flag',
    build: () => ThemeCubit(box),
    act: (cubit) => cubit.setDark(true),
    expect: () => [
      isA<ThemeState>().having((s) => s.themeMode, 'mode', ThemeMode.dark),
    ],
    verify: (_) => verify(() => box.put('isDarkMode', true)).called(1),
  );

  blocTest<ThemeCubit, ThemeState>(
    'setDark(false) from a dark start emits light mode',
    build: () {
      when(() => box.get('isDarkMode', defaultValue: false)).thenReturn(true);
      return ThemeCubit(box);
    },
    act: (cubit) => cubit.setDark(false),
    expect: () => [
      isA<ThemeState>().having((s) => s.themeMode, 'mode', ThemeMode.light),
    ],
    verify: (_) => verify(() => box.put('isDarkMode', false)).called(1),
  );
}
