import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/seller_product.dart';

// Local design tokens for the seller product preview — thin facades over the
// central seller palette in [AppColors] so the preview stays visually
// consistent with the rest of the seller surface and never reaches for a
// customer-brand accent.
const Color kInk = AppColors.sellerInk;
const Color kGrey = AppColors.sellerGrey;
const Color kGreyMid = AppColors.sellerGreyMid;
const Color kGreySoft = AppColors.sellerGreySoft;
const Color kDivider = AppColors.sellerDividerStrong;
const Color kOutline = AppColors.sellerOutline;
const Color kSurfaceMuted = AppColors.sellerFillSoft;
const Color kImageBg = AppColors.sellerImageBg;

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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
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
      style: const TextStyle(
        fontFamily: AppFonts.seller,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: kInk,
        letterSpacing: -0.2,
        height: 1.2,
      ),
    );
  }
}
