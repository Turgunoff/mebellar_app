import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// Compact card with the two pieces of identity info a seller looks for at a
/// glance: the human-friendly product code (renamed from "SKU" so it doesn't
/// read as warehouse jargon) and the resolved category name.
///
/// Stock used to live here but Mebellar is made-to-order — no stock count to
/// surface, so the row was removed.
class MetaCard extends StatelessWidget {
  const MetaCard({
    super.key,
    required this.sku,
    required this.category,
  });

  final String sku;
  final String category;

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
            "Mahsulot kodi nusxa olindi",
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
                      'Mahsulot kodi',
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
                    const SizedBox(height: 2),
                    const Text(
                      'Buyurtmalarda va omborda mahsulotni topish uchun',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: kGreyMid,
                        height: 1.25,
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
        ],
      ),
    );
  }
}
