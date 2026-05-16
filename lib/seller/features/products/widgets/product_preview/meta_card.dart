import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// SKU (copyable), category and stock count — mirrors the fields the seller
/// list tile exposes so the preview confirms what's saved.
class MetaCard extends StatelessWidget {
  const MetaCard({
    super.key,
    required this.sku,
    required this.category,
    required this.stock,
  });

  final String sku;
  final String category;
  final int stock;

  Future<void> _copySku(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: sku));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: kInk,
          content: const Text(
            "SKU nusxa olindi",
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: 'Asosiy ma\'lumotlar'),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Iconsax.barcode, size: 18, color: kGrey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SKU',
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
                      sku,
                      style: const TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                        height: 1.2,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: kSurfaceMuted,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => _copySku(context),
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Iconsax.copy, size: 16, color: kInk),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: kDivider),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Iconsax.category, size: 18, color: kGrey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kategoriya',
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
                      category,
                      style: const TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: kDivider),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Iconsax.box, size: 18, color: kGrey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ombor qoldig\'i',
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
                      '$stock dona',
                      style: const TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (stock > 0 && stock <= 3)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1D6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Kam qoldi',
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8C5A12),
                      height: 1.0,
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
