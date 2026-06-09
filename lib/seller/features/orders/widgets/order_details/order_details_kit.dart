import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';

// Local design tokens for the order-details screen — a thin facade over the
// central seller palette in [AppColors].
//
// Only the FIXED (brightness-independent) tokens live here as `const` aliases:
// the amber pill and the soft indigo accent read the same on light and dark.
// The ADAPTIVE colours (ink / greys / dividers / surfaces / image bg) are NOT
// here — every consuming widget grabs `final c = SellerColors.of(context)` at
// the top of its `build` and reads `c.ink` / `c.grey` / `c.dividerStrong` /
// `c.outline` / `c.fillSoft` / `c.imageBg`, so they flip with the theme.
// Jakarta Sans is applied to every `Text` explicitly so the surface is immune
// to seller-theme tint regressions.

// Amber pill — soft tint, saturated text. Don't darken [kAmberFg] without
// re-checking contrast against [kAmberBg].
const Color kAmberBg = AppColors.sellerWarningBg;
const Color kAmberFg = AppColors.sellerWarning;

// Soft indigo tint for active step rings & accent backgrounds.
const Color kAccentSoft = AppColors.sellerPrimaryTint;

/// Rounded, soft-shadowed card wrapping an order-details section. The surface
/// flips with the theme via [SellerColors].
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Bold heading inside a [SectionCard].
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.seller,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: SellerColors.of(context).ink,
        letterSpacing: -0.2,
        height: 1.2,
      ),
    );
  }
}

/// One physical line item within an order, as displayed in `ItemsCard`.
/// The seller order-detail screen maps the domain `OrderItem` onto this
/// presentation struct.
@immutable
class OrderItem {
  const OrderItem({
    required this.name,
    required this.qty,
    required this.unitPriceLabel,
    required this.subtotalLabel,
    this.thumbnail = '',
    this.colorSlug = '',
  });

  final String name;
  final int qty;
  final String unitPriceLabel;
  final String subtotalLabel;

  /// First product image URL. Empty string means show the placeholder icon.
  final String thumbnail;

  /// Canonical colour slug the customer ordered, or empty when the product
  /// has no colour palette.
  final String colorSlug;
}
