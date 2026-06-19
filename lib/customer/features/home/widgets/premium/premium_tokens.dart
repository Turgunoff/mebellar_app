import 'package:flutter/material.dart';
import '../../../../../core/theme/app_fonts.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme_extension.dart';

/// Customer-mode token bag — the call-site sugar over the app's [ThemeData] and
/// [AppCustomColors] extension.
///
/// Every adaptive colour here is now sourced from the **active theme**, so there
/// is a single source of truth: change a colour in [AppTheme] / [AppColors] and
/// it flows through here automatically. Read it per build:
///
/// ```dart
/// final pt = PremiumTokens.of(context);
/// Container(color: pt.surface);          // theme `colorScheme.surface`
/// Container(color: pt.card);             // inverted dark card token
/// ```
///
/// Brand accents (`accent`, `accentDeep`), shadows and the text-style factories
/// stay static — they don't flip with brightness.
class PremiumTokens {
  PremiumTokens._(this._scheme, this._custom, this._isDark);

  final ColorScheme _scheme;
  final AppCustomColors _custom;
  final bool _isDark;

  factory PremiumTokens.of(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumTokens._(
      theme.colorScheme,
      theme.extension<AppCustomColors>() ?? AppCustomColors.light,
      theme.brightness == Brightness.dark,
    );
  }

  // ---- Adaptive tokens — delegated to the theme ----------------------------
  // Values are unchanged from the previous hand-rolled versions; they now read
  // from `colorScheme` / `AppCustomColors` so the theme is the only source.

  /// Scaffold / page background (`#FAFAFA` light, `#121212` dark).
  Color get background => _scheme.surfaceContainerLowest;

  /// Default panel surface (`#FFFFFF` light, `#1E1E1E` dark). NOTE: this stays
  /// light in light mode — for the brand *dark* card use [card].
  Color get surface => _scheme.surface;

  /// Primary text / ink (`#1D1D1D` light, `#F5F5F5` dark).
  Color get dark => _scheme.onSurface;

  /// Secondary text (`#757575` light, `#A0A0A0` dark).
  Color get grey => _scheme.onSurfaceVariant;

  /// Faintest text / disabled glyphs. No semantic ColorScheme slot, so it keeps
  /// its explicit pair.
  Color get greyLight =>
      _isDark ? const Color(0xFF6B6B6B) : const Color(0xFFBDBDBD);

  /// Neutral fill behind imagery while it loads.
  Color get imageBg => _custom.imageBackground;

  /// Hairline divider.
  Color get divider => _custom.dividerSoft;

  // ---- Inverted dark card + semantic helpers -------------------------------

  /// The brand "inverted" card surface — dark in both themes (the panels seen on
  /// product detail / profile / checkout / shop profile).
  Color get card => _custom.customCardBackground;

  /// Foreground (text + icons) on [card].
  Color get onCard => _custom.customCardText;

  /// Green used for positive status text ("Sotuvda mavjud", "Tasdiqlangan").
  Color get success => _custom.successText;

  /// Soft-green *fill* for a positive badge / chip ("Yetkazildi").
  Color get successBg => _custom.successContainer;

  /// Deep-green foreground on [successBg].
  Color get onSuccessBg => _custom.onSuccessContainer;

  /// Telegram contact button background.
  Color get telegram => _custom.telegramButton;

  /// Foreground on [telegram].
  Color get onTelegram => _custom.onTelegramButton;

  /// Phone-call ("Qo'ng'iroq") button background.
  Color get call => _custom.callButton;

  /// Foreground on [call].
  Color get onCall => _custom.onCallButton;

  // ---- Brand constants — same in both modes --------------------------------

  static const Color accent = AppColors.terracotta;
  static const Color accentDeep = AppColors.terracottaDeep;

  /// Fixed brand-success emerald (CTA / "approved" gradient). Like [accent] it
  /// does not flip with brightness — emerald reads fine on both backgrounds.
  static const Color successStrong = AppColors.successStrong;
  static const Color successStrongDeep = AppColors.successStrongDeep;

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
  }) => TextStyle(
    fontFamily: AppFonts.display,
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
  }) => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}
