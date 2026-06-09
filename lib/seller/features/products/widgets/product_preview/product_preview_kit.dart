import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/seller_product.dart';

// Local design tokens for the seller product preview. Adaptive neutrals (ink,
// greys, dividers, surfaces, image bg) flip with light/dark — read them from
// `SellerColors.of(context)`: ink→c.ink, grey→c.grey, greyMid→c.greyMid,
// greySoft→c.greySoft, divider→c.dividerStrong, outline→c.outline,
// surfaceMuted→c.fillSoft, imageBg→c.imageBg. Only the brand accent stays
// const here — it reads fine on both backgrounds.

/// Soft indigo tint behind the "customer view" banner — the seller brand
/// accent at low intensity.
const Color kAccentSoft = AppColors.sellerPrimaryTint;

/// Status palette — kept aligned with `ProductStatusChip` so the preview's
/// banner pill matches the list-tile pill exactly.
({Color bg, Color fg, IconData icon, String label}) statusPalette(
  SellerProductStatus status,
) {
  return switch (status) {
    SellerProductStatus.draft => (
      bg: AppColors.sellerNeutralBgAlt,
      fg: AppColors.sellerNeutralFgAlt,
      icon: Iconsax.edit,
      label: 'Qoralama',
    ),
    SellerProductStatus.pendingReview => (
      bg: AppColors.sellerWarningBg,
      fg: AppColors.sellerWarning,
      icon: Iconsax.clock,
      label: 'Tekshirilmoqda',
    ),
    SellerProductStatus.approved => (
      bg: AppColors.sellerPositiveBg,
      fg: AppColors.sellerPositive,
      icon: Iconsax.tick_circle,
      label: 'Tasdiqlangan',
    ),
    SellerProductStatus.rejected => (
      bg: AppColors.sellerNegativeBg,
      fg: AppColors.sellerNegative,
      icon: Iconsax.close_circle,
      label: 'Rad etilgan',
    ),
    SellerProductStatus.archived => (
      bg: AppColors.sellerNeutralBg,
      fg: AppColors.sellerNeutralFg,
      icon: Iconsax.archive_2,
      label: 'Arxivlangan',
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
