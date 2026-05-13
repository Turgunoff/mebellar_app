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
}
