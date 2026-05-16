import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/category_model.dart';
import 'form_kit.dart';

/// Modal bottom sheet for picking the product category. Pops the chosen
/// [CategoryModel].
class CategoryPickerSheet extends StatelessWidget {
  const CategoryPickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.accent,
  });

  final String title;
  final List<CategoryModel> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kInk,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: kDivider),
                itemBuilder: (_, i) => _CategoryTile(
                  category: items[i],
                  accent: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.accent});

  final CategoryModel category;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(category),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(Iconsax.category, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const Icon(
              Iconsax.arrow_right_3,
              size: 18,
              color: kGreyMid,
            ),
          ],
        ),
      ),
    );
  }
}
