import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../i18n/i18n.dart';
import 'theme_cubit.dart';

/// Localised label for a [ThemeMode] — used for the settings row's trailing
/// text and the picker tiles. System / Light / Dark, in the active UI language.
String themeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.system:
      return tr('settings.theme_system');
    case ThemeMode.light:
      return tr('settings.theme_light');
    case ThemeMode.dark:
      return tr('settings.theme_dark');
  }
}

IconData _themeModeIcon(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.system:
      return Icons.brightness_auto_rounded;
    case ThemeMode.light:
      return Icons.light_mode_rounded;
    case ThemeMode.dark:
      return Icons.dark_mode_rounded;
  }
}

/// Shared three-way theme picker (System / Light / Dark) used by both the
/// customer and seller settings screens. Mirrors [showLanguagePicker]:
/// theme-agnostic (reads `Theme.of(context)`, so it renders correctly in
/// either mode and in light/dark) and writes the choice through the global
/// [ThemeCubit], which persists it and rebuilds both MaterialApps instantly.
Future<void> showThemeModePicker(BuildContext context) {
  // Capture the cubit from the calling context — the modal route is pushed on
  // the root navigator and can't see the settings screen's provider scope.
  final cubit = context.read<ThemeCubit>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _ThemeModeSheet(cubit: cubit),
  );
}

class _ThemeModeSheet extends StatelessWidget {
  const _ThemeModeSheet({required this.cubit});

  final ThemeCubit cubit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = cubit.state.themeMode;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              tr('settings.theme_title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // ThemeMode.values is [system, light, dark] — the order the task asks
          // for (System first, then Light, then Dark).
          for (final mode in ThemeMode.values)
            ListTile(
              onTap: () async {
                await cubit.setThemeMode(mode);
                if (context.mounted) Navigator.of(context).pop();
              },
              leading: Icon(
                _themeModeIcon(mode),
                color: mode == current ? theme.colorScheme.primary : null,
              ),
              title: Text(themeModeLabel(mode)),
              trailing: mode == current
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
