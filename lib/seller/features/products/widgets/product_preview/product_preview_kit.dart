import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/seller_product.dart';

// Local design tokens for the seller product preview. Mirrors the
// order_details palette so seller surfaces stay visually consistent.
const Color kInk = Color(0xFF1D1D1D);
const Color kGrey = Color(0xFF757575);
const Color kGreyMid = Color(0xFFBDBDBD);
const Color kGreySoft = Color(0xFFB0B0B0);
const Color kDivider = Color(0xFFEAEAEA);
const Color kOutline = Color(0xFFE3E3E3);
const Color kSurfaceMuted = Color(0xFFF5F5F5);
const Color kImageBg = Color(0xFFF0F0F0);
const Color kTerracottaSoft = Color(0xFFFBEDE6);

/// Status palette — kept aligned with `ProductStatusChip` so the preview's
/// banner pill matches the list-tile pill exactly.
({Color bg, Color fg, IconData icon, String label}) statusPalette(
  SellerProductStatus status,
) {
  return switch (status) {
    SellerProductStatus.draft => (
        bg: const Color(0xFFF1F1F1),
        fg: const Color(0xFF555555),
        icon: Iconsax.edit,
        label: 'Qoralama',
      ),
    SellerProductStatus.pendingReview => (
        bg: const Color(0xFFFFF1D6),
        fg: const Color(0xFF8C5A12),
        icon: Iconsax.clock,
        label: 'Tekshirilmoqda',
      ),
    SellerProductStatus.approved => (
        bg: const Color(0xFFDCF1E5),
        fg: const Color(0xFF1F6B49),
        icon: Iconsax.tick_circle,
        label: 'Tasdiqlangan',
      ),
    SellerProductStatus.rejected => (
        bg: const Color(0xFFFDECEA),
        fg: const Color(0xFFC0392B),
        icon: Iconsax.close_circle,
        label: 'Rad etilgan',
      ),
    SellerProductStatus.archived => (
        bg: const Color(0xFFEDEDED),
        fg: const Color(0xFF8A8A8A),
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

/// Mock product bundled so the preview renders without a repository or bloc.
/// Swap to real data when the API contract lands.
@immutable
class PreviewMockProduct {
  const PreviewMockProduct({
    required this.title,
    required this.priceLabel,
    required this.oldPriceLabel,
    required this.discountPercent,
    required this.stock,
    required this.images,
  });

  final String title;
  final String priceLabel;
  final String? oldPriceLabel;
  final int discountPercent;
  final int stock;
  final List<String> images;
}

const kPreviewMockProduct = PreviewMockProduct(
  title: 'Klassik kuxnya jihozlari',
  priceLabel: '9 800 000',
  oldPriceLabel: '11 200 000',
  discountPercent: 13,
  stock: 2,
  images: [
    'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=900',
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=900',
    'https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=900',
    'https://images.unsplash.com/photo-1558211583-d26f610c1eb1?w=900',
  ],
);
