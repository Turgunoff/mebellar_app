import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeState {
  const ThemeState(this.themeMode);
  final ThemeMode themeMode;
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit(this._box) : super(_initial(_box));

  final Box _box;
  static const _key = 'isDarkMode';

  static ThemeState _initial(Box box) {
    final isDark = box.get(_key, defaultValue: false) as bool;
    return ThemeState(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setDark(bool isDark) async {
    await _box.put(_key, isDark);
    emit(ThemeState(isDark ? ThemeMode.dark : ThemeMode.light));
  }

  bool get isDark => state.themeMode == ThemeMode.dark;
}
