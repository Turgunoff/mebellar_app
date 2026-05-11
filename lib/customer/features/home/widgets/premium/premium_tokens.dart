import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';

/// Static brand tokens (accent colors, shadows, text-style factories).
///
/// **Adaptive surface/text colors must be accessed via the instance API:**
/// ```dart
/// final pt = PremiumTokens.of(context);
/// Container(color: pt.surface);
/// ```
/// Never use the old static `PremiumTokens.surface` etc. in new code — those
/// constants are light-only and will look broken in dark mode.
class PremiumTokens {
  PremiumTokens._(this._isDark);

  final bool _isDark;

  factory PremiumTokens.of(BuildContext context) =>
      PremiumTokens._(Theme.of(context).brightness == Brightness.dark);

  // ---- Adaptive surface/text tokens ---------------------------------------

  Color get background =>
      _isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA);
  Color get surface =>
      _isDark ? AppColors.darkSurface : Colors.white;
  Color get dark =>
      _isDark ? AppColors.darkTextPrimary : const Color(0xFF1D1D1D);
  Color get grey =>
      _isDark ? AppColors.darkTextSecondary : const Color(0xFF757575);
  Color get greyLight =>
      _isDark ? const Color(0xFF6B6B6B) : const Color(0xFFBDBDBD);
  Color get imageBg =>
      _isDark ? AppColors.darkImageBg : const Color(0xFFF0F0F0);
  Color get divider =>
      _isDark ? AppColors.darkDivider : const Color(0xFFEAEAEA);

  // ---- Brand constants — same in both modes --------------------------------

  static const Color accent = Color(0xFFC27A5F);
  static const Color accentDeep = Color(0xFFB85C38);

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -8,
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 32,
          offset: const Offset(0, 12),
          spreadRadius: -10,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  // ---- Text-style factories -------------------------------------------------
  // `color` defaults to null, meaning the widget inherits from DefaultTextStyle
  // (which is set by the theme). Pass `color: pt.dark` only when you need an
  // explicit shade that differs from the default.

  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.15,
    double letterSpacing = -0.5,
  }) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.35,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
}
