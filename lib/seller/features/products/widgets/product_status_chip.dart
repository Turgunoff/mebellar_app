import 'package:flutter/material.dart';
import 'package:mebellar_app/core/i18n/i18n.dart';

import '../../../../shared/models/seller_product.dart';

/// Status pill used on the seller products list and detail.
///
/// Palette is hand-picked rather than derived from the [ColorScheme] so the
/// chip stays on-brand even when the seller theme's seed shifts. The label
/// inherits the seller theme's Plus Jakarta Sans family — `fontFamily` is
/// intentionally omitted so a single theme-level swap propagates here.
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
    final palette = _palette(status);
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

  ({Color bg, Color fg}) _palette(SellerProductStatus status) {
    return switch (status) {
      SellerProductStatus.draft => (
          bg: const Color(0xFFF1F1F1),
          fg: const Color(0xFF555555),
        ),
      SellerProductStatus.pendingReview => (
          bg: const Color(0xFFFFF1D6),
          fg: const Color(0xFF8C5A12),
        ),
      SellerProductStatus.approved => (
          bg: const Color(0xFFDCF1E5),
          fg: const Color(0xFF1F6B49),
        ),
      SellerProductStatus.rejected => (
          bg: const Color(0xFFFDECEA),
          fg: const Color(0xFFC0392B),
        ),
      SellerProductStatus.archived => (
          bg: const Color(0xFFEDEDED),
          fg: const Color(0xFF8A8A8A),
        ),
    };
  }
}
