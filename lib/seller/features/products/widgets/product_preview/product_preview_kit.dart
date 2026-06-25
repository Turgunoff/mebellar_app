import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/i18n/i18n.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/seller_product.dart';

// Local design tokens for the seller product preview. Every colour flips with
// light/dark — read them from `SellerColors.of(context)`: ink→c.ink, grey→c.grey,
// greyMid→c.greyMid, greySoft→c.greySoft, divider→c.dividerStrong,
// outline→c.outline, surfaceMuted→c.fillSoft, imageBg→c.imageBg, and the
// "customer view" banner accent disc → c.primarySoft / c.onPrimarySoft.

/// Status palette — kept aligned with `ProductStatusChip` so the preview's
/// banner pill matches the list-tile pill exactly.
// Resolved from [SellerColors] (not raw [AppColors] consts) so the neutral
// draft / archived pills flip with the theme instead of pinning the light grey
// — the status-intent fills (warning / positive / negative) read the same on
// both backgrounds but go through the resolver too for consistency.
({Color bg, Color fg, IconData icon, String label}) statusPalette(
  SellerColors c,
  SellerProductStatus status,
) {
  return switch (status) {
    SellerProductStatus.draft => (
      bg: c.neutralBgAlt,
      fg: c.neutralFgAlt,
      icon: Iconsax.edit,
      label: tr('common.draft'),
    ),
    SellerProductStatus.pendingReview => (
      bg: c.warningBg,
      fg: c.warning,
      icon: Iconsax.clock,
      label: tr('common.pending_review'),
    ),
    SellerProductStatus.approved => (
      bg: c.positiveBg,
      fg: c.positive,
      icon: Iconsax.tick_circle,
      label: tr('common.approved'),
    ),
    SellerProductStatus.rejected => (
      bg: c.negativeBg,
      fg: c.negative,
      icon: Iconsax.close_circle,
      label: tr('common.rejected'),
    ),
    SellerProductStatus.archived => (
      bg: c.neutralBg,
      fg: c.neutralFg,
      icon: Iconsax.archive_2,
      label: tr('common.archived'),
    ),
  };
}

/// White, rounded, soft-shadowed card wrapping a preview section.
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
    final c = SellerColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.seller,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: c.ink,
        letterSpacing: -0.2,
        height: 1.2,
      ),
    );
  }
}
