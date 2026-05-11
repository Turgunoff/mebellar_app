import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brand colors that don't map onto Material 3's [ColorScheme].
///
/// Material 3 covers primary/secondary/tertiary/surface/error/etc., but a
/// premium brand layer needs a few more tokens: a translucent tint for
/// glassmorphism, a softer divider than `outlineVariant`, dedicated success
/// and warning colors, and an image-placeholder fill.
///
/// Pulled from [Theme] so it pivots with light/dark automatically:
///
/// ```dart
/// final custom = Theme.of(context).extension<AppCustomColors>()!;
/// container.color = custom.glassBackground;
/// ```
@immutable
class AppCustomColors extends ThemeExtension<AppCustomColors> {
  const AppCustomColors({
    required this.glassBackground,
    required this.dividerSoft,
    required this.imageBackground,
    required this.success,
    required this.warning,
    required this.error,
  });

  /// Translucent fill for frosted-glass surfaces (bottom nav, app bars).
  /// Pair with a `BackdropFilter` to get the actual blur.
  final Color glassBackground;

  /// Hairline divider between sections inside a card. Quieter than the
  /// scheme's `outlineVariant` so it reads as separation, not structure.
  final Color dividerSoft;

  /// Neutral fill behind product imagery while it loads or errors out.
  final Color imageBackground;

  /// Positive status color (delivered, in-stock, paid).
  final Color success;

  /// Cautionary status color (pending, low-stock, action required).
  final Color warning;

  /// Negative status color. Mirrors `colorScheme.error` for components that
  /// can't reach the scheme directly (e.g. inside a widget that only sees
  /// the extension).
  final Color error;

  /// Defaults for [Brightness.light]. Composed in `app_theme.dart`.
  static const light = AppCustomColors(
    glassBackground: AppColors.lightGlass,
    dividerSoft: AppColors.lightDivider,
    imageBackground: AppColors.lightImageBg,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.danger,
  );

  /// Defaults for [Brightness.dark].
  static const dark = AppCustomColors(
    glassBackground: AppColors.darkGlass,
    dividerSoft: AppColors.darkDivider,
    imageBackground: AppColors.darkImageBg,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.danger,
  );

  @override
  AppCustomColors copyWith({
    Color? glassBackground,
    Color? dividerSoft,
    Color? imageBackground,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return AppCustomColors(
      glassBackground: glassBackground ?? this.glassBackground,
      dividerSoft: dividerSoft ?? this.dividerSoft,
      imageBackground: imageBackground ?? this.imageBackground,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  /// Linearly interpolates between `this` and [other]. Drives the smooth
  /// crossfade Flutter performs when [Theme] animates from light to dark.
  @override
  AppCustomColors lerp(ThemeExtension<AppCustomColors>? other, double t) {
    if (other is! AppCustomColors) return this;
    return AppCustomColors(
      glassBackground:
          Color.lerp(glassBackground, other.glassBackground, t) ?? glassBackground,
      dividerSoft: Color.lerp(dividerSoft, other.dividerSoft, t) ?? dividerSoft,
      imageBackground:
          Color.lerp(imageBackground, other.imageBackground, t) ?? imageBackground,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
    );
  }
}

/// Sugar so call sites read `context.customColors.glassBackground` instead of
/// `Theme.of(context).extension<AppCustomColors>()!.glassBackground`.
extension AppCustomColorsX on BuildContext {
  AppCustomColors get customColors =>
      Theme.of(this).extension<AppCustomColors>()!;
}
