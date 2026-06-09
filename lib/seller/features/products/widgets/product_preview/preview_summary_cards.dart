import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/seller_product.dart';
import 'product_preview_kit.dart';

/// Leading strip telling the seller this is the customer-facing view.
class PreviewModeBanner extends StatelessWidget {
  const PreviewModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: kAccentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.sellerPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.eye, size: 18, color: AppColors.sellerPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Mijoz ko'rinishi",
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sellerPrimary,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Mahsulotingiz xaridorlarga qanday ko'rinishini tekshiring",
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.sellerPrimaryDeep,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Moderation-state pill + last-updated timestamp.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.status,
    required this.updatedAtLabel,
  });

  final SellerProductStatus status;
  final String updatedAtLabel;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final palette = statusPalette(status);
    return SectionCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(palette.icon, size: 14, color: palette.fg),
                const SizedBox(width: 6),
                Text(
                  palette.label,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.fg,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Icon(Iconsax.refresh, size: 13, color: c.greySoft),
          const SizedBox(width: 6),
          Text(
            updatedAtLabel,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.grey,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Title, current price, strike-through old price, discount pill and an
/// availability badge. Built directly from the live [SellerProduct] so the
/// preview matches what's persisted in the DB.
class TitlePriceCard extends StatelessWidget {
  const TitlePriceCard({super.key, required this.product});

  final SellerProduct product;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final priceFormat = NumberFormat('#,###', 'uz');
    final hasDiscount =
        product.discountPrice != null &&
        product.discountPrice! > 0 &&
        product.discountPrice! < product.price;
    final effectivePrice = hasDiscount ? product.discountPrice! : product.price;
    final discountPercent = hasDiscount
        ? (((product.price - product.discountPrice!) / product.price) * 100)
              .round()
        : 0;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name.get('uz'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: c.ink,
              letterSpacing: -0.4,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  text: priceFormat.format(effectivePrice),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                  children: [
                    TextSpan(
                      text: '  UZS',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.greyMid,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    "${priceFormat.format(product.price)} UZS",
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.greySoft,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: c.greySoft,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (hasDiscount) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-$discountPercent%',
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFC0392B),
                  height: 1.0,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: c.dividerStrong),
          const SizedBox(height: 14),
          // Woody's catalog is made-to-order — every product is rendered
          // as "available" once the moderator approves it; otherwise we
          // surface the moderation state instead of a fake stock count.
          Row(
            children: [
              Icon(
                product.status == SellerProductStatus.approved
                    ? Iconsax.tick_circle
                    : Iconsax.clock,
                size: 16,
                color: product.status == SellerProductStatus.approved
                    ? const Color(0xFF1F6B49)
                    : const Color(0xFF8C5A12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  product.status == SellerProductStatus.approved
                      ? 'Sotuvda mavjud · buyurtma bo\'yicha tayyorlanadi'
                      : 'Hozircha sotuvda emas',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: product.status == SellerProductStatus.approved
                        ? const Color(0xFF1F6B49)
                        : const Color(0xFF8C5A12),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Soft-red callout surfacing the admin's rejection reason. Shown on the detail
/// screen only when the product is rejected and a reason was recorded — the
/// seller needs to read why before re-submitting.
class RejectionReasonCard extends StatelessWidget {
  const RejectionReasonCard({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3C9C3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.info_circle, size: 18, color: Color(0xFFC0392B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rad etish sababi',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC0392B),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB23B2E),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
