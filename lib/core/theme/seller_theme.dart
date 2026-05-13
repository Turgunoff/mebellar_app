import 'package:flutter/material.dart';
import 'app_fonts.dart';

import 'app_colors.dart';
import 'app_theme.dart' show appSystemOverlay;
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
///     the call below and the four `TextStyle(fontFamily: AppFonts.seller, ...)` lines
///     — the screens don't need to change.
ThemeData _build(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  // Explicit ColorScheme construction (not `fromSeed`) so the seller brand
  // stays exactly on-spec — `fromSeed` would interpolate the Deep Indigo
  // through Material's tonal palette and we'd lose the saturated business
  // accent the dashboard relies on.
  final scheme = ColorScheme(
    brightness: brightness,
    primary: AppColors.sellerPrimary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.sellerPrimaryDeep,
    onPrimaryContainer: Colors.white,
    secondary: AppColors.sellerPrimaryDeep,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.sellerPrimaryTint,
    onSecondaryContainer: AppColors.sellerPrimaryDeep,
    tertiary: AppColors.sellerPrimaryDeep,
    onTertiary: Colors.white,
    error: AppColors.danger,
    onError: Colors.white,
    surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    onSurface:
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
    surfaceContainerLowest:
        isDark ? AppColors.darkBackground : AppColors.lightBackground,
    surfaceContainerLow:
        isDark ? AppColors.darkSurface : AppColors.lightSurface,
    surfaceContainer:
        isDark ? AppColors.darkSurface : AppColors.lightSurface,
    surfaceContainerHigh:
        isDark ? AppColors.darkImageBg : AppColors.lightImageBg,
    surfaceContainerHighest:
        isDark ? AppColors.darkImageBg : AppColors.lightImageBg,
    onSurfaceVariant:
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
    outline: isDark ? AppColors.darkDivider : AppColors.lightDivider,
    outlineVariant:
        isDark ? AppColors.darkDivider : AppColors.lightDivider,
    surfaceTint: Colors.transparent,
  );

  final textTheme = AppTypography.plusJakartaSansTextTheme(brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isDark ? AppColors.darkBackground : AppColors.lightBackground,
    canvasColor:
        isDark ? AppColors.darkBackground : AppColors.lightBackground,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(fontFamily: AppFonts.seller,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      toolbarTextStyle: TextStyle(fontFamily: AppFonts.seller,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      systemOverlayStyle: appSystemOverlay(brightness),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size.fromHeight(52),
        textStyle: TextStyle(fontFamily: AppFonts.seller,
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
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary, width: 1),
        textStyle: TextStyle(fontFamily: AppFonts.seller,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: TextStyle(fontFamily: AppFonts.seller,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      filled: true,
      labelStyle: TextStyle(fontFamily: AppFonts.seller, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(fontFamily: AppFonts.seller, fontWeight: FontWeight.w400),
    ),
    progressIndicatorTheme:
        ProgressIndicatorThemeData(color: scheme.primary),
    iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
  );
}

final ThemeData sellerLightTheme = _build(Brightness.light);
final ThemeData sellerDarkTheme = _build(Brightness.dark);
