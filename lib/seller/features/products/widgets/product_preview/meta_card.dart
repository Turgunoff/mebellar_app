import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// Compact card with the two pieces of identity info a seller looks for at a
/// glance: the human-friendly product code (renamed from "SKU" so it doesn't
/// read as warehouse jargon) and the resolved category name.
///
/// Stock used to live here but Woody is made-to-order — no stock count to
/// surface, so the row was removed.
class MetaCard extends StatelessWidget {
  const MetaCard({
    super.key,
    this.sku,
    required this.category,
    this.subcategory,
    this.material,
  });

  /// Internal product code (SKU). Seller-only — the customer detail screen
  /// passes null, so the code row + copy button are omitted there.
  final String? sku;
  final String category;

  /// Resolved subcategory name; null/blank rows are omitted so an empty column
  /// never shows.
  final String? subcategory;

  /// Primary material text (`products.material`); omitted when blank.
  final String? material;

  Future<void> _copySku(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
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
    final code = sku?.trim();
    final hasSku = code != null && code.isNotEmpty;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: 'Asosiy ma\'lumotlar'),
          const SizedBox(height: 14),
          if (hasSku)
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
                        code,
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
                    onTap: () => _copySku(context, code),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Iconsax.copy, size: 16, color: kInk),
                    ),
                  ),
                ),
              ],
            ),
          _MetaInfoRow(
            icon: Iconsax.category,
            label: 'Kategoriya',
            value: category,
            // No leading divider when this is the card's first row (no SKU).
            showDivider: hasSku,
          ),
          if ((subcategory?.trim().isNotEmpty ?? false))
            _MetaInfoRow(
              icon: Iconsax.category_2,
              label: 'Subkategoriya',
              value: subcategory!.trim(),
            ),
          if ((material?.trim().isNotEmpty ?? false))
            _MetaInfoRow(
              icon: Iconsax.box_1,
              label: 'Material',
              value: material!.trim(),
            ),
        ],
      ),
    );
  }
}

/// A divider-prefixed icon + label/value row inside [MetaCard]. The leading
/// divider keeps the rows visually separated without a trailing divider after
/// the last one. [showDivider] is false for the first row in the card (so it
/// doesn't draw a divider right under the section title).
class _MetaInfoRow extends StatelessWidget {
  const _MetaInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDivider) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: kDivider),
        ],
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: kGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 3),
                  Text(
                    value,
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
    );
  }
}
