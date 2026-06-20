import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/app_settings.dart';

class ThemeState {
  const ThemeState(this.themeMode);
  final ThemeMode themeMode;
}

/// Global, single source of truth for the app's [ThemeMode]. Registered once
/// in the root DI scope and provided above Phoenix, so the customer and seller
/// surfaces share the exact same instance — toggling dark mode in either mode
/// updates both and persists across cold starts.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit(this._settings) : super(ThemeState(_settings.themeMode));

  final AppSettings _settings;

  ThemeMode get themeMode => state.themeMode;

  /// Persists [mode] and emits it. No-ops when unchanged so listeners don't
  /// rebuild needlessly. The single entry point for the settings picker —
  /// callers choose between [ThemeMode.system], `.light` and `.dark` directly.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state.themeMode) return;
    await _settings.setThemeMode(mode);
    emit(ThemeState(mode));
  }
}
