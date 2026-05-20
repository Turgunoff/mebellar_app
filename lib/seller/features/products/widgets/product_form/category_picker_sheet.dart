import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/category_model.dart';
import 'form_kit.dart';

/// Modal bottom sheet for picking a single category. Pops the chosen
/// [CategoryModel]. Subcategory selection is handled by [SubcategoryPickerSheet]
/// in a second sheet so the form gets two independent picker fields rather
/// than a single drill-down — easier to navigate when the user wants to
/// change subcategory without re-confirming the parent category.
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
    return _PickerSheetShell(
      title: title,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: kDivider),
        itemBuilder: (_, i) => _CategoryTile(
          name: items[i].name,
          accent: accent,
          onTap: () => Navigator.of(context).pop(items[i]),
        ),
      ),
    );
  }
}

/// Modal bottom sheet for picking a subcategory inside [parentName]. Returns
/// `null` if the user dismisses, the selected [SubcategoryModel] if picked,
/// or a sentinel value via [subcategories]+null-check pattern for "clear".
class SubcategoryPickerSheet extends StatelessWidget {
  const SubcategoryPickerSheet({
    super.key,
    required this.parentName,
    required this.subcategories,
    required this.selectedId,
    required this.accent,
  });

  final String parentName;
  final List<SubcategoryModel> subcategories;
  final String? selectedId;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _PickerSheetShell(
      title: parentName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Clear" row — pops with null result, the caller treats it as
          // "no subcategory" (category-only product).
          _ClearTile(
            selected: selectedId == null,
            accent: accent,
            onTap: () => Navigator.of(context).pop(_ClearSubcategorySentinel()),
          ),
          if (subcategories.isNotEmpty)
            const Divider(height: 1, color: kDivider),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: subcategories.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: kDivider),
              itemBuilder: (_, i) => _CategoryTile(
                name: subcategories[i].name,
                accent: accent,
                trailingSelected: subcategories[i].id == selectedId,
                onTap: () => Navigator.of(context).pop(subcategories[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sentinel result returned by [SubcategoryPickerSheet] when the user
/// explicitly clears the selection. The caller distinguishes this from a
/// dismiss (which returns `null`).
class _ClearSubcategorySentinel {
  const _ClearSubcategorySentinel();
}

/// Convenience marker so screen code can be type-safe without exposing the
/// private sentinel class outside this file.
const Object clearSubcategorySelection = _ClearSubcategorySentinel();

bool isClearSubcategoryResult(Object? value) =>
    value is _ClearSubcategorySentinel;

class _PickerSheetShell extends StatelessWidget {
  const _PickerSheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

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
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.name,
    required this.accent,
    required this.onTap,
    this.trailingSelected = false,
  });

  final String name;
  final Color accent;
  final VoidCallback onTap;
  final bool trailingSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
                name,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            if (trailingSelected)
              Icon(Iconsax.tick_circle, size: 20, color: accent),
          ],
        ),
      ),
    );
  }
}

class _ClearTile extends StatelessWidget {
  const _ClearTile({
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            const Icon(Iconsax.close_circle, size: 20, color: kGreyMid),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Subkategoriyasiz',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kGrey,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            if (selected)
              Icon(Iconsax.tick_circle, size: 20, color: accent),
          ],
        ),
      ),
    );
  }
}
