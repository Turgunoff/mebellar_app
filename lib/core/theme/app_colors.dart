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

  // ---- Success container (badge / chip fill + text) -----------------------
  // Soft-green fill with a deep-green foreground for "delivered" / "in stock"
  // pills. Split from [success] (a saturated fill) so a low-contrast container
  // can be tuned for both themes independently. Consumed via
  // [AppCustomColors.successContainer] / `.onSuccessContainer`.
  static const Color successContainer = Color(0xFFDCEFDC);
  static const Color onSuccessContainer = Color(0xFF1B5E20);
  static const Color successContainerDark = Color(0xFF14331B);
  static const Color onSuccessContainerDark = Color(0xFFA5D6A7);

  // ---- Warning container (cautionary banner fill + text) ------------------
  // Soft amber fill + deep amber foreground for cautionary banners (fee
  // adjustment, action required). Split into a light/dark pair so the banner
  // flips with the theme instead of staying a bright cream island in dark mode.
  // Consumed via [AppCustomColors.warningContainer] / `.onWarningContainer`.
  static const Color warningContainer = Color(0xFFFFF8EE);
  static const Color onWarningContainer = Color(0xFF8C5A12);
  static const Color warningContainerDark = Color(0xFF3A2D12);
  static const Color onWarningContainerDark = Color(0xFFF5C77A);

  // ---- Success accent (emerald CTA / gradient) ----------------------------
  // Fixed brand-success emerald used for the "seller approved" gradient banner.
  // Like [terracotta], it does NOT flip with brightness — emerald reads fine on
  // both backgrounds. Exposed as static `PremiumTokens.successStrong` constants.
  static const Color successStrong = Color(0xFF2F9E6E);
  static const Color successStrongDeep = Color(0xFF237955);

  // ---- Customer "inverted" card surface -----------------------------------
  // By design the customer cards (product detail, profile rows, checkout,
  // shop profile) read DARK in BOTH themes: in light mode they sit as
  // near-black panels on the off-white scaffold; in dark mode they reuse the
  // normal dark surface, a touch above the near-black background. Consumed via
  // [AppCustomColors.customCardBackground] / `.customCardText` — never let a
  // widget hardcode these again.
  static const Color cardSurfaceLight = Color(0xFF1A1A1A);
  static const Color cardSurfaceDark = darkSurface; // #1E1E1E, above #121212 bg
  static const Color cardForeground = Color(0xFFF5F5F5);

  // ---- Contact / social action colors -------------------------------------
  // Telegram brand blue and the phone-call CTA yellow seen on the shop-profile
  // action row. Exposed through [AppCustomColors] so the buttons theme with the
  // rest of the app instead of carrying inline hex.
  static const Color telegram = Color(0xFF2AABEE);
  static const Color onTelegram = Color(0xFFFFFFFF);
  static const Color callYellow = Color(0xFFF4B400);
  static const Color onCallYellow = Color(0xFF1A1A1A);

  // ---- Legacy seeds -------------------------------------------------------
  // Retained for seller_theme.dart's `fromSeed` palette. The customer mode no
  // longer seeds — AppTheme builds its ColorScheme explicitly from [terracotta].
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

/// Seller-mode colour set, resolved per [Brightness].
///
/// Registered as a [ThemeExtension] on both `sellerLightTheme` and
/// `sellerDarkTheme` (see `seller_theme.dart`), so every seller widget reads
/// its colours from `SellerColors.of(context)` and flips automatically with
/// the theme. The per-feature `*_kit.dart` facades expose these through
/// context-aware helpers.
///
/// **Adaptive** fields (ink / greys / surfaces / dividers / neutrals / locked
/// / track) carry separate light & dark values. **Fixed** tokens (brand indigo,
/// status intents, gold, medals, chart series) are getters returning the same
/// [AppColors] constant in both modes — they read fine on either background.
@immutable
class SellerColors extends ThemeExtension<SellerColors> {
  const SellerColors({
    required this.ink,
    required this.grey,
    required this.greyFaint,
    required this.greyMid,
    required this.greySoft,
    required this.background,
    required this.surface,
    required this.divider,
    required this.dividerStrong,
    required this.outline,
    required this.fillSoft,
    required this.fillFaint,
    required this.imageBg,
    required this.neutralFg,
    required this.neutralBg,
    required this.neutralFgAlt,
    required this.neutralBgAlt,
    required this.lockedBg,
    required this.ringTrack,
    required this.trackBg,
  });

  // ---- Adaptive (light/dark) tokens ---------------------------------------
  final Color ink;
  final Color grey;
  final Color greyFaint;
  final Color greyMid;
  final Color greySoft;
  final Color background;
  final Color surface;
  final Color divider;
  final Color dividerStrong;
  final Color outline;
  final Color fillSoft;
  final Color fillFaint;
  final Color imageBg;
  final Color neutralFg;
  final Color neutralBg;
  final Color neutralFgAlt;
  final Color neutralBgAlt;
  final Color lockedBg;
  final Color ringTrack;
  final Color trackBg;

  // ---- Fixed tokens (identical on both backgrounds) -----------------------
  Color get primary => AppColors.sellerPrimary;
  Color get primaryDeep => AppColors.sellerPrimaryDeep;
  Color get primaryTint => AppColors.sellerPrimaryTint;
  Color get primaryBright => AppColors.sellerPrimaryBright;

  Color get positive => AppColors.sellerPositive;
  Color get positiveBg => AppColors.sellerPositiveBg;
  Color get negative => AppColors.sellerNegative;
  Color get negativeBg => AppColors.sellerNegativeBg;
  Color get warning => AppColors.sellerWarning;
  Color get warningBg => AppColors.sellerWarningBg;
  Color get progress => AppColors.sellerProgress;
  Color get progressBg => AppColors.sellerProgressBg;
  Color get gold => AppColors.sellerGold;
  Color get goldBright => AppColors.sellerGoldBright;
  Color get goldBg => AppColors.sellerGoldBg;
  Color get silver => AppColors.sellerSilver;
  Color get silverBg => AppColors.sellerSilverBg;
  Color get bronze => AppColors.sellerBronze;
  Color get bronzeBg => AppColors.sellerBronzeBg;
  List<Color> get chartPalette => AppColors.sellerChartPalette;

  static const SellerColors light = SellerColors(
    ink: AppColors.sellerInk,
    grey: AppColors.sellerGrey,
    greyFaint: AppColors.sellerGreyFaint,
    greyMid: AppColors.sellerGreyMid,
    greySoft: AppColors.sellerGreySoft,
    background: AppColors.sellerBackground,
    surface: AppColors.sellerSurface,
    divider: AppColors.sellerDivider,
    dividerStrong: AppColors.sellerDividerStrong,
    outline: AppColors.sellerOutline,
    fillSoft: AppColors.sellerFillSoft,
    fillFaint: AppColors.sellerFillFaint,
    imageBg: AppColors.sellerImageBg,
    neutralFg: AppColors.sellerNeutralFg,
    neutralBg: AppColors.sellerNeutralBg,
    neutralFgAlt: AppColors.sellerNeutralFgAlt,
    neutralBgAlt: AppColors.sellerNeutralBgAlt,
    lockedBg: AppColors.sellerLockedBg,
    ringTrack: AppColors.sellerRingTrack,
    trackBg: AppColors.sellerTrackBg,
  );

  static const SellerColors dark = SellerColors(
    ink: AppColors.sellerInkDark,
    grey: AppColors.sellerGreyDark,
    greyFaint: AppColors.sellerGreyFaintDark,
    greyMid: AppColors.sellerGreyMidDark,
    greySoft: AppColors.sellerGreySoftDark,
    background: AppColors.sellerBackgroundDark,
    surface: AppColors.sellerSurfaceDark,
    divider: AppColors.sellerDividerDark,
    dividerStrong: AppColors.sellerDividerStrongDark,
    outline: AppColors.sellerOutlineDark,
    fillSoft: AppColors.sellerFillSoftDark,
    fillFaint: AppColors.sellerFillFaintDark,
    imageBg: AppColors.sellerImageBgDark,
    neutralFg: AppColors.sellerNeutralFgDark,
    neutralBg: AppColors.sellerNeutralBgDark,
    neutralFgAlt: AppColors.sellerNeutralFgAltDark,
    neutralBgAlt: AppColors.sellerNeutralBgAltDark,
    lockedBg: AppColors.sellerLockedBgDark,
    ringTrack: AppColors.sellerRingTrackDark,
    trackBg: AppColors.sellerTrackBgDark,
  );

  /// Reads the active set from the nearest seller theme. Falls back to [light]
  /// if the extension isn't registered (e.g. a widget pumped outside the
  /// seller theme in a test) so callers never hit a null.
  static SellerColors of(BuildContext context) =>
      Theme.of(context).extension<SellerColors>() ?? light;

  /// Picks a set by raw [Brightness] — for painters/tests without a context.
  static SellerColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  SellerColors copyWith({
    Color? ink,
    Color? grey,
    Color? greyFaint,
    Color? greyMid,
    Color? greySoft,
    Color? background,
    Color? surface,
    Color? divider,
    Color? dividerStrong,
    Color? outline,
    Color? fillSoft,
    Color? fillFaint,
    Color? imageBg,
    Color? neutralFg,
    Color? neutralBg,
    Color? neutralFgAlt,
    Color? neutralBgAlt,
    Color? lockedBg,
    Color? ringTrack,
    Color? trackBg,
  }) {
    return SellerColors(
      ink: ink ?? this.ink,
      grey: grey ?? this.grey,
      greyFaint: greyFaint ?? this.greyFaint,
      greyMid: greyMid ?? this.greyMid,
      greySoft: greySoft ?? this.greySoft,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      divider: divider ?? this.divider,
      dividerStrong: dividerStrong ?? this.dividerStrong,
      outline: outline ?? this.outline,
      fillSoft: fillSoft ?? this.fillSoft,
      fillFaint: fillFaint ?? this.fillFaint,
      imageBg: imageBg ?? this.imageBg,
      neutralFg: neutralFg ?? this.neutralFg,
      neutralBg: neutralBg ?? this.neutralBg,
      neutralFgAlt: neutralFgAlt ?? this.neutralFgAlt,
      neutralBgAlt: neutralBgAlt ?? this.neutralBgAlt,
      lockedBg: lockedBg ?? this.lockedBg,
      ringTrack: ringTrack ?? this.ringTrack,
      trackBg: trackBg ?? this.trackBg,
    );
  }

  @override
  SellerColors lerp(ThemeExtension<SellerColors>? other, double t) {
    if (other is! SellerColors) return this;
    return SellerColors(
      ink: Color.lerp(ink, other.ink, t)!,
      grey: Color.lerp(grey, other.grey, t)!,
      greyFaint: Color.lerp(greyFaint, other.greyFaint, t)!,
      greyMid: Color.lerp(greyMid, other.greyMid, t)!,
      greySoft: Color.lerp(greySoft, other.greySoft, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dividerStrong: Color.lerp(dividerStrong, other.dividerStrong, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      fillSoft: Color.lerp(fillSoft, other.fillSoft, t)!,
      fillFaint: Color.lerp(fillFaint, other.fillFaint, t)!,
      imageBg: Color.lerp(imageBg, other.imageBg, t)!,
      neutralFg: Color.lerp(neutralFg, other.neutralFg, t)!,
      neutralBg: Color.lerp(neutralBg, other.neutralBg, t)!,
      neutralFgAlt: Color.lerp(neutralFgAlt, other.neutralFgAlt, t)!,
      neutralBgAlt: Color.lerp(neutralBgAlt, other.neutralBgAlt, t)!,
      lockedBg: Color.lerp(lockedBg, other.lockedBg, t)!,
      ringTrack: Color.lerp(ringTrack, other.ringTrack, t)!,
      trackBg: Color.lerp(trackBg, other.trackBg, t)!,
    );
  }
}
