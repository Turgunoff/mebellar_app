import 'package:flutter/material.dart';

import 'i18n.dart';

/// Shared language picker used by both the customer and seller settings
/// screens. Lists every supported locale by its native name, marks the active
/// one, and writes the choice through [AppLocaleController] — which persists it
/// and rebuilds both MaterialApps instantly (no restart).
///
/// Theme-agnostic: it reads `Theme.of(context)`, so it renders correctly in
/// either mode and in light/dark.
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = context.locale.languageCode;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              tr('settings.language_title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final locale in AppTranslations.supportedLocales)
            _LanguageTile(
              code: locale.languageCode,
              selected: locale.languageCode == current,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.code, required this.selected});

  final String code;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: () async {
        await maybeAppLocaleController()?.setLocale(Locale(code));
        if (context.mounted) Navigator.of(context).pop();
      },
      // Native names (`lang.uz` → "O'zbekcha") read identically in every
      // bundle, so the list is legible whatever the current UI language is.
      title: Text(tr('lang.$code')),
      trailing: selected
          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
          : null,
    );
  }
}
