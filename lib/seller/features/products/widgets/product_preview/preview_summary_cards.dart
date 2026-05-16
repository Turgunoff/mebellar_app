import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

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
        color: kTerracottaSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.terracotta.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.eye, size: 18, color: AppColors.terracotta),
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
                    color: AppColors.terracotta,
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
                    color: const Color(0xFF8A4A35),
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
          const Icon(Iconsax.refresh, size: 13, color: kGreySoft),
          const SizedBox(width: 6),
          Text(
            updatedAtLabel,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kGrey,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Title, current price, strike-through old price, discount pill and an
/// in-stock indicator.
class TitlePriceCard extends StatelessWidget {
  const TitlePriceCard({super.key, required this.product});

  final PreviewMockProduct product;

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        product.oldPriceLabel != null && product.oldPriceLabel!.isNotEmpty;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.title,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kInk,
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
                  text: product.priceLabel,
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                  children: const [
                    TextSpan(
                      text: '  UZS',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kGreyMid,
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
                    "${product.oldPriceLabel!} UZS",
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kGreySoft,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: kGreySoft,
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
                '-${product.discountPercent}%',
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
          const Divider(height: 1, thickness: 1, color: kDivider),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                product.stock > 0
                    ? Iconsax.tick_circle
                    : Iconsax.close_circle,
                size: 16,
                color: product.stock > 0
                    ? const Color(0xFF1F6B49)
                    : const Color(0xFFC0392B),
              ),
              const SizedBox(width: 8),
              Text(
                product.stock > 0
                    ? 'Sotuvda mavjud · ${product.stock} dona'
                    : 'Sotuvda yo\'q',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: product.stock > 0
                      ? const Color(0xFF1F6B49)
                      : const Color(0xFFC0392B),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
