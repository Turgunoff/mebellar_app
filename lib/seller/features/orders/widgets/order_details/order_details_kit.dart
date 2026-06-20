import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';

// Local design tokens for the order-details screen — every colour flips with
// the theme. Each consuming widget grabs `final c = SellerColors.of(context)`
// at the top of its `build` and reads the adaptive tokens (`c.ink` / `c.grey` /
// `c.dividerStrong` / `c.outline` / `c.fillSoft` / `c.imageBg`), the status
// intents (`c.warningBg` / `c.warning`, …) and the brand accent disc
// (`c.primarySoft` / `c.onPrimarySoft`). Nothing is pinned to a fixed light
// tint here. Jakarta Sans is applied to every `Text` explicitly so the surface
// is immune to seller-theme tint regressions.

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
