import 'package:flutter/material.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/seller_product.dart';

/// Status pill used on the seller products list and detail.
///
/// Colours come from the brightness-aware [SellerColors] status intents so the
/// pill flips with the theme (soft tint in light, low-luminance tint in dark)
/// instead of glowing as a light island. The label inherits the seller theme's
/// Plus Jakarta Sans family — `fontFamily` is intentionally omitted so a single
/// theme-level swap propagates here.
class ProductStatusChip extends StatelessWidget {
  const ProductStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final SellerProductStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(status, SellerColors.of(context));
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 13 : 15, color: palette.fg),
          const SizedBox(width: 4),
          Text(
            tr('seller_product_status.${status.code}'),
            style: TextStyle(
              color: palette.fg,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 13,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  ({Color bg, Color fg}) _palette(SellerProductStatus status, SellerColors c) {
    return switch (status) {
      SellerProductStatus.draft => (bg: c.neutralBgAlt, fg: c.neutralFgAlt),
      SellerProductStatus.pendingReview => (bg: c.warningBg, fg: c.warning),
      SellerProductStatus.approved => (bg: c.positiveBg, fg: c.positive),
      SellerProductStatus.rejected => (bg: c.negativeBg, fg: c.negative),
      SellerProductStatus.archived => (bg: c.neutralBg, fg: c.neutralFg),
    };
  }
}
