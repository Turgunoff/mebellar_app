import 'package:flutter/material.dart';

/// Raw color tokens.
///
/// Do not consume these directly in widgets — they are inputs to
/// [AppTheme] and [AppCustomColors]. Reading from `Theme.of(context)` keeps
/// every widget light/dark-aware automatically; reading [AppColors] does not.
class AppColors {
  const AppColors._();

  // ---- Brand --------------------------------------------------------------
  /// Customer brand accent — used as `ColorScheme.primary` in both modes.
  static const Color terracotta = Color(0xFFC27A5F);

  /// Pressed / hovered shade of the brand accent.
  static const Color terracottaDeep = Color(0xFFB85C38);

  // ---- Light palette ------------------------------------------------------
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1D1D1D);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightDivider = Color(0xFFEAEAEA);
  static const Color lightImageBg = Color(0xFFF0F0F0);

  /// White at 70% — `0xB3` ≈ 0.70. Encoded as a const literal because
  /// `withValues(alpha: 0.7)` is not a const expression and ThemeExtensions
  /// require const colors for their static defaults.
  static const Color lightGlass = Color(0xB3FFFFFF);

  // ---- Dark palette -------------------------------------------------------
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFA0A0A0);
  static const Color darkDivider = Color(0xFF2A2A2A);
  static const Color darkImageBg = Color(0xFF242424);

  /// Dark surface at 70% opacity for glassmorphism on dark mode.
  static const Color darkGlass = Color(0xB31E1E1E);

  // ---- Semantic -----------------------------------------------------------
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // ---- Legacy seeds -------------------------------------------------------
  // Retained so the existing seller_theme.dart and customer_theme.dart
  // continue to compile while the codebase migrates to AppTheme.
  static const Color customerSeed = Color(0xFF8B5E3C);
  static const Color sellerSeed = Color(0xFF3949AB);

  // ---- Seller business palette --------------------------------------------
  // Deep Indigo, intentionally far from the customer Terracotta so the user
  // instantly registers the mode switch as "Backoffice". Used by
  // [seller_theme.dart] and by every seller-side surface that previously
  // hardcoded [terracotta] (bottom nav, KPI accents, CTA buttons).
  //
  // Why Indigo over teal: teal reads as a consumer/wellness accent; indigo
  // reads as enterprise/fintech — the right register for an inventory and
  // analytics surface.
  static const Color sellerPrimary = Color(0xFF3949AB);
  static const Color sellerPrimaryDeep = Color(0xFF283593);
  static const Color sellerPrimaryTint = Color(0xFFE8EAF6);

  /// Lighter indigo used as the top stop of the seller hero/header gradients.
  static const Color sellerPrimaryBright = Color(0xFF4554C4);

  // ---- Seller semantic palette --------------------------------------------
  // Single source for every non-brand colour the seller surface uses: ink,
  // greys, dividers, status intents, the achievement gold, and the chart
  // series. Defined as light/dark pairs so dark mode can be switched on later
  // by reading the `*Dark` variant — the brand indigo and the status intents
  // are perceptually fine on both backgrounds, so they don't split.
  //
  // Consumed through [SellerColors] (the resolver below) and the per-feature
  // `*_kit.dart` facades — seller widgets must NOT pull `terracotta` or any
  // customer token, so the modes stay visually distinct.

  // Ink / text — light.
  static const Color sellerInk = Color(0xFF1D1D1D);
  static const Color sellerGrey = Color(0xFF757575);
  static const Color sellerGreyFaint = Color(0xFF9E9E9E);
  static const Color sellerGreyMid = Color(0xFFBDBDBD);
  static const Color sellerGreySoft = Color(0xFFB0B0B0);
  // Ink / text — dark.
  static const Color sellerInkDark = Color(0xFFF5F5F5);
  static const Color sellerGreyDark = Color(0xFFA8A8A8);
  static const Color sellerGreyFaintDark = Color(0xFF8E8E8E);
  static const Color sellerGreyMidDark = Color(0xFF6E6E6E);
  static const Color sellerGreySoftDark = Color(0xFF7A7A7A);

  // Surfaces / lines — light.
  static const Color sellerBackground = Color(0xFFFAFAFA);
  static const Color sellerSurface = Color(0xFFFFFFFF);
  static const Color sellerDivider = Color(0xFFEFEFEF);
  static const Color sellerDividerStrong = Color(0xFFEAEAEA);
  static const Color sellerOutline = Color(0xFFE3E3E3);
  static const Color sellerFillSoft = Color(0xFFF5F5F5);
  static const Color sellerFillFaint = Color(0xFFF7F7F7);
  static const Color sellerImageBg = Color(0xFFF0F0F0);

  /// Neutral chip (draft / archived / disabled state) — fg over a soft grey.
  static const Color sellerNeutralFg = Color(0xFF8A8A8A);
  static const Color sellerNeutralBg = Color(0xFFEDEDED);
  static const Color sellerNeutralFgAlt = Color(0xFF555555);
  static const Color sellerNeutralBgAlt = Color(0xFFF1F1F1);
  // Surfaces / lines — dark.
  static const Color sellerBackgroundDark = Color(0xFF121212);
  static const Color sellerSurfaceDark = Color(0xFF1E1E1E);
  static const Color sellerDividerDark = Color(0xFF2A2A2A);
  static const Color sellerDividerStrongDark = Color(0xFF323232);
  static const Color sellerOutlineDark = Color(0xFF383838);
  static const Color sellerFillSoftDark = Color(0xFF242424);
  static const Color sellerFillFaintDark = Color(0xFF202020);
  static const Color sellerImageBgDark = Color(0xFF242424);
  // Neutral chip — dark.
  static const Color sellerNeutralFgDark = Color(0xFF9A9A9A);
  static const Color sellerNeutralBgDark = Color(0xFF2C2C2C);
  static const Color sellerNeutralFgAltDark = Color(0xFFB0B0B0);
  static const Color sellerNeutralBgAltDark = Color(0xFF262626);
  // Locked badge / ring / progress track — dark.
  static const Color sellerLockedBgDark = Color(0xFF2A2A2E);
  static const Color sellerRingTrackDark = Color(0xFF323236);
  static const Color sellerTrackBgDark = Color(0xFF2E2E32);

  // Status intents (shared across light/dark — fg over a soft tint bg).
  static const Color sellerPositive = Color(0xFF1F6B49);
  static const Color sellerPositiveBg = Color(0xFFDCF1E5);
  static const Color sellerNegative = Color(0xFFC0392B);
  static const Color sellerNegativeBg = Color(0xFFFDECEA);
  static const Color sellerWarning = Color(0xFF8C5A12);
  static const Color sellerWarningBg = Color(0xFFFFF1D6);
  static const Color sellerGold = Color(0xFFE0A106);
  static const Color sellerGoldBright = Color(0xFFFFCB52);
  static const Color sellerGoldBg = Color(0xFFFFF3D6);

  /// "In progress" intent (shipped / preparing order pills) — a violet that
  /// reads as active-but-neutral, distinct from the success green.
  static const Color sellerProgress = Color(0xFF5B21B6);
  static const Color sellerProgressBg = Color(0xFFEDE3FF);

  /// Neutral disc behind a *locked* achievement badge / ring track.
  static const Color sellerLockedBg = Color(0xFFF1F1F4);
  static const Color sellerRingTrack = Color(0xFFEDEDF0);

  /// Track behind a linear progress bar on the seller surface.
  static const Color sellerTrackBg = Color(0xFFF0F0F2);

  // Leaderboard medals (silver / bronze; gold reuses [sellerGold]).
  static const Color sellerSilver = Color(0xFF8A94A6);
  static const Color sellerSilverBg = Color(0xFFEDF0F4);
  static const Color sellerBronze = Color(0xFFB06B3A);
  static const Color sellerBronzeBg = Color(0xFFF6E7DA);

  /// Indigo-first chart series — replaces the old terracotta-led palette so
  /// seller analytics never paints a customer-brand slice.
  static const List<Color> sellerChartPalette = <Color>[
    sellerPrimary, // #3949AB
    Color(0xFF2C3E50),
    Color(0xFFF39C12),
    sellerPositive, // green
    Color(0xFF7E57C2),
    sellerGreyMid,
  ];
}

/// Resolver that picks the right seller token for a [Brightness].
///
/// Seller widgets currently read colours statically (through the per-feature
/// `*_kit.dart` facades, which point at [SellerColors.light]). Keeping the
/// dark set defined here means switching the whole seller surface to dark mode
/// later is a one-line change in each kit (`SellerColors.light` →
/// `SellerColors.of(context)`), not a hunt for scattered hex literals.
class SellerColors {
  const SellerColors({
    required this.ink,
    required this.grey,
    required this.greyMid,
    required this.greySoft,
    required this.background,
    required this.surface,
    required this.divider,
    required this.outline,
    required this.fillSoft,
    required this.imageBg,
  });

  // Adaptive (light/dark) tokens.
  final Color ink;
  final Color grey;
  final Color greyMid;
  final Color greySoft;
  final Color background;
  final Color surface;
  final Color divider;
  final Color outline;
  final Color fillSoft;
  final Color imageBg;

  // Brand — identical on both backgrounds.
  Color get primary => AppColors.sellerPrimary;
  Color get primaryDeep => AppColors.sellerPrimaryDeep;
  Color get primaryTint => AppColors.sellerPrimaryTint;
  Color get primaryBright => AppColors.sellerPrimaryBright;

  // Status intents — identical on both backgrounds.
  Color get positive => AppColors.sellerPositive;
  Color get positiveBg => AppColors.sellerPositiveBg;
  Color get negative => AppColors.sellerNegative;
  Color get negativeBg => AppColors.sellerNegativeBg;
  Color get warning => AppColors.sellerWarning;
  Color get warningBg => AppColors.sellerWarningBg;
  Color get gold => AppColors.sellerGold;
  Color get goldBright => AppColors.sellerGoldBright;
  Color get goldBg => AppColors.sellerGoldBg;

  static const SellerColors light = SellerColors(
    ink: AppColors.sellerInk,
    grey: AppColors.sellerGrey,
    greyMid: AppColors.sellerGreyMid,
    greySoft: AppColors.sellerGreySoft,
    background: AppColors.sellerBackground,
    surface: AppColors.sellerSurface,
    divider: AppColors.sellerDivider,
    outline: AppColors.sellerOutline,
    fillSoft: AppColors.sellerFillSoft,
    imageBg: AppColors.sellerImageBg,
  );

  static const SellerColors dark = SellerColors(
    ink: AppColors.sellerInkDark,
    grey: AppColors.sellerGreyDark,
    greyMid: AppColors.sellerGreyMidDark,
    greySoft: AppColors.sellerGreySoftDark,
    background: AppColors.sellerBackgroundDark,
    surface: AppColors.sellerSurfaceDark,
    divider: AppColors.sellerDividerDark,
    outline: AppColors.sellerOutlineDark,
    fillSoft: AppColors.sellerFillSoftDark,
    imageBg: AppColors.sellerImageBgDark,
  );

  /// Resolves from a [Brightness] — use once seller screens read
  /// `Theme.of(context).brightness`. For now the kits use [light] directly.
  static SellerColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
