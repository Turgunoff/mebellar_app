import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Seller-mode theme.
///
/// Independent from the customer theme on purpose — sellers spend hours in
/// data-heavy screens and need a calmer, more "tool-like" surface than the
/// customer storefront. The two themes share `AppColors` for brand tokens
/// but nothing else; they don't `extend` each other so a styling change on
/// one side can never accidentally regress the other.
///
/// Typography:
///   * `Plus Jakarta Sans` is the seller mode's universal family. It's
///     applied through `AppTypography.plusJakartaSansTextTheme(...)`, which
///     also pre-bakes the weight ramp (display/headline → w700–w800 for
///     KPI numbers, body → w500 for subtitles, label → w600 for buttons).
///   * Component-level text styles (AppBar title, buttons, inputs) are
///     pinned to Plus Jakarta Sans explicitly because their defaults don't
///     always pick up the theme's `textTheme` family.
///   * Seller UI files (e.g. `dashboard_screen.dart`, `kpi_card.dart`) use
///     plain `TextStyle(...)` without `fontFamily`, so the family inherits
///     from this theme. To swap the seller font in the future, edit *only*
///     the call below and the four `GoogleFonts.plusJakartaSans(...)` lines
///     — the screens don't need to change.
ThemeData _build(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.sellerSeed,
    brightness: brightness,
  );

  final textTheme = AppTypography.plusJakartaSansTextTheme(brightness);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      toolbarTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
      hintStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400),
    ),
  );
}

final ThemeData sellerLightTheme = _build(Brightness.light);
final ThemeData sellerDarkTheme = _build(Brightness.dark);
