import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// Four-up grid of length / width / height / weight tiles.
class DimensionsCard extends StatelessWidget {
  const DimensionsCard({
    super.key,
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
    required this.weightKg,
  });

  final num lengthCm;
  final num widthCm;
  final num heightCm;
  final num weightKg;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: "O'lchamlari va og'irligi"),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DimensionTile(
                  icon: Iconsax.ruler,
                  label: 'Uzunligi',
                  value: '$lengthCm sm',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DimensionTile(
                  icon: Iconsax.size,
                  label: 'Kengligi',
                  value: '$widthCm sm',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DimensionTile(
                  icon: Iconsax.maximize_3,
                  label: 'Balandligi',
                  value: '$heightCm sm',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DimensionTile(
                  icon: Iconsax.weight,
                  label: 'Og\'irligi',
                  value: '$weightKg kg',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DimensionTile extends StatelessWidget {
  const _DimensionTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: kGrey),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: kGrey,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kInk,
              letterSpacing: -0.2,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal product id + creation timestamp — a compact bottom strip.
class IdentifiersCard extends StatelessWidget {
  const IdentifiersCard({
    super.key,
    required this.productId,
    required this.createdAtLabel,
  });

  final String productId;
  final String createdAtLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mahsulot ID',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: kGrey,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  productId,
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Yaratilgan',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: kGrey,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                createdAtLabel,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kInk,
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
