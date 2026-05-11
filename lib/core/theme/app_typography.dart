import 'package:flutter/material.dart';

import 'app_fonts.dart';

class AppTypography {
  const AppTypography._();

  /// Material default text theme without a brand font applied — used by the
  /// customer mode, which inherits its family from the customer theme.
  static TextTheme textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.whiteMountainView
        : Typography.blackMountainView;
    return base.apply(fontFamily: null);
  }

  /// Plus Jakarta Sans–applied text theme used by the seller mode.
  ///
  /// Applies the family to every Material text role and then overrides the
  /// weights so the seller UI reads like a premium SaaS / FinTech tool:
  ///
  ///   * `display*` / `headline*` — extra-bold (w800) so KPI numbers and
  ///     hero metrics dominate the visual hierarchy.
  ///   * `title*`                 — bold (w700) for screen / section titles.
  ///   * `body*`                  — medium (w500) for subtitles and copy,
  ///     which keeps secondary text legible without competing with numbers.
  ///   * `label*`                 — semibold (w600) for buttons and chips.
  ///
  /// Centralizing the weight ramp here means a future font change is a
  /// one-line edit — the calling theme just swaps the family.
  static TextTheme plusJakartaSansTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.whiteMountainView
        : Typography.blackMountainView;
    final familied = base.apply(fontFamily: AppFonts.seller);

    return familied.copyWith(
      // Hero numbers — KPI values, dashboard headlines.
      displayLarge: familied.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      displayMedium: familied.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      displaySmall: familied.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      headlineLarge: familied.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      headlineMedium: familied.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      headlineSmall: familied.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),

      // Section / screen titles.
      titleLarge: familied.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: familied.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: familied.titleSmall?.copyWith(fontWeight: FontWeight.w600),

      // Subtitles and descriptive copy.
      bodyLarge: familied.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: familied.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      bodySmall: familied.bodySmall?.copyWith(fontWeight: FontWeight.w500),

      // Buttons, chips, captions.
      labelLarge: familied.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: familied.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: familied.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
