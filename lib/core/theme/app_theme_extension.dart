import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brand colors that don't map onto Material 3's [ColorScheme].
///
/// Material 3 covers primary/secondary/tertiary/surface/error/etc., but the
/// Woody customer surface needs a few more tokens: a translucent tint for
/// glassmorphism, a softer divider than `outlineVariant`, dedicated semantic
/// colors, an image-placeholder fill, the **inverted dark card** (cards read
/// dark in light mode by design) and the Telegram / phone-call action colors.
///
/// This is the single `AppColorsExtension` for the customer mode — register it
/// once in [AppTheme] and pull it anywhere it flips with light/dark:
///
/// ```dart
/// final custom = Theme.of(context).extension<AppCustomColors>()!;
/// container.color = custom.customCardBackground;
/// // or the sugar: context.customColors.customCardBackground
/// ```
@immutable
class AppCustomColors extends ThemeExtension<AppCustomColors> {
  const AppCustomColors({
    required this.glassBackground,
    required this.dividerSoft,
    required this.imageBackground,
    required this.success,
    required this.successText,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.error,
    required this.customCardBackground,
    required this.customCardText,
    required this.telegramButton,
    required this.onTelegramButton,
    required this.callButton,
    required this.onCallButton,
  });

  /// Translucent fill for frosted-glass surfaces (bottom nav, app bars).
  /// Pair with a `BackdropFilter` to get the actual blur.
  final Color glassBackground;

  /// Hairline divider between sections inside a card. Quieter than the
  /// scheme's `outlineVariant` so it reads as separation, not structure.
  final Color dividerSoft;

  /// Neutral fill behind product imagery while it loads or errors out.
  final Color imageBackground;

  /// Positive status color used as a *fill* (delivered, in-stock, paid).
  final Color success;

  /// Positive status color tuned for *text* ("Sotuvda mavjud",
  /// "Tasdiqlangan"). Split from [success] so a text shade can be darkened for
  /// contrast later without disturbing the fills.
  final Color successText;

  /// Soft-green *fill* behind a positive badge / chip ("Yetkazildi", "Sotuvda
  /// mavjud"). Pair with [onSuccessContainer] for the label + icon.
  final Color successContainer;

  /// Deep-green foreground (text + icon) that sits on [successContainer].
  final Color onSuccessContainer;

  /// Cautionary status color (pending, low-stock, action required).
  final Color warning;

  /// Negative status color. Mirrors `colorScheme.error` for components that
  /// can't reach the scheme directly (e.g. inside a widget that only sees
  /// the extension).
  final Color error;

  /// The "inverted" card surface. Dark in BOTH themes by design: near-black on
  /// the light scaffold, the normal dark surface in dark mode. This is the
  /// brand card look across product detail / profile / checkout / shop profile.
  final Color customCardBackground;

  /// Foreground (text + icons) that sits on [customCardBackground]. White-ish
  /// in both themes since the card is always dark.
  final Color customCardText;

  /// Background for the Telegram contact button (shop profile action row).
  final Color telegramButton;

  /// Foreground (label + icon) on [telegramButton].
  final Color onTelegramButton;

  /// Background for the phone-call ("Qo'ng'iroq") contact button.
  final Color callButton;

  /// Foreground (label + icon) on [callButton] — dark, for contrast on yellow.
  final Color onCallButton;

  /// Defaults for [Brightness.light]. Registered in `app_theme.dart`.
  static const light = AppCustomColors(
    glassBackground: AppColors.lightGlass,
    dividerSoft: AppColors.lightDivider,
    imageBackground: AppColors.lightImageBg,
    success: AppColors.success,
    successText: AppColors.success,
    successContainer: AppColors.successContainer,
    onSuccessContainer: AppColors.onSuccessContainer,
    warning: AppColors.warning,
    error: AppColors.danger,
    customCardBackground: AppColors.cardSurfaceLight,
    customCardText: AppColors.cardForeground,
    telegramButton: AppColors.telegram,
    onTelegramButton: AppColors.onTelegram,
    callButton: AppColors.callYellow,
    onCallButton: AppColors.onCallYellow,
  );

  /// Defaults for [Brightness.dark].
  static const dark = AppCustomColors(
    glassBackground: AppColors.darkGlass,
    dividerSoft: AppColors.darkDivider,
    imageBackground: AppColors.darkImageBg,
    success: AppColors.success,
    successText: AppColors.success,
    successContainer: AppColors.successContainerDark,
    onSuccessContainer: AppColors.onSuccessContainerDark,
    warning: AppColors.warning,
    error: AppColors.danger,
    customCardBackground: AppColors.cardSurfaceDark,
    customCardText: AppColors.cardForeground,
    telegramButton: AppColors.telegram,
    onTelegramButton: AppColors.onTelegram,
    callButton: AppColors.callYellow,
    onCallButton: AppColors.onCallYellow,
  );

  @override
  AppCustomColors copyWith({
    Color? glassBackground,
    Color? dividerSoft,
    Color? imageBackground,
    Color? success,
    Color? successText,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? error,
    Color? customCardBackground,
    Color? customCardText,
    Color? telegramButton,
    Color? onTelegramButton,
    Color? callButton,
    Color? onCallButton,
  }) {
    return AppCustomColors(
      glassBackground: glassBackground ?? this.glassBackground,
      dividerSoft: dividerSoft ?? this.dividerSoft,
      imageBackground: imageBackground ?? this.imageBackground,
      success: success ?? this.success,
      successText: successText ?? this.successText,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      customCardBackground: customCardBackground ?? this.customCardBackground,
      customCardText: customCardText ?? this.customCardText,
      telegramButton: telegramButton ?? this.telegramButton,
      onTelegramButton: onTelegramButton ?? this.onTelegramButton,
      callButton: callButton ?? this.callButton,
      onCallButton: onCallButton ?? this.onCallButton,
    );
  }

  /// Linearly interpolates between `this` and [other]. Drives the smooth
  /// crossfade Flutter performs when [Theme] animates from light to dark.
  @override
  AppCustomColors lerp(ThemeExtension<AppCustomColors>? other, double t) {
    if (other is! AppCustomColors) return this;
    return AppCustomColors(
      glassBackground:
          Color.lerp(glassBackground, other.glassBackground, t) ??
          glassBackground,
      dividerSoft: Color.lerp(dividerSoft, other.dividerSoft, t) ?? dividerSoft,
      imageBackground:
          Color.lerp(imageBackground, other.imageBackground, t) ??
          imageBackground,
      success: Color.lerp(success, other.success, t) ?? success,
      successText: Color.lerp(successText, other.successText, t) ?? successText,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t) ??
          successContainer,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t) ??
          onSuccessContainer,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
      customCardBackground:
          Color.lerp(customCardBackground, other.customCardBackground, t) ??
          customCardBackground,
      customCardText:
          Color.lerp(customCardText, other.customCardText, t) ?? customCardText,
      telegramButton:
          Color.lerp(telegramButton, other.telegramButton, t) ?? telegramButton,
      onTelegramButton:
          Color.lerp(onTelegramButton, other.onTelegramButton, t) ??
          onTelegramButton,
      callButton: Color.lerp(callButton, other.callButton, t) ?? callButton,
      onCallButton:
          Color.lerp(onCallButton, other.onCallButton, t) ?? onCallButton,
    );
  }
}

/// Sugar so call sites read `context.customColors.customCardBackground` instead
/// of `Theme.of(context).extension<AppCustomColors>()!.customCardBackground`.
extension AppCustomColorsX on BuildContext {
  AppCustomColors get customColors =>
      Theme.of(this).extension<AppCustomColors>() ?? AppCustomColors.light;
}
