import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'form_kit.dart';

/// Name, category, subcategory and description fields.
class BasicInfoSection extends StatelessWidget {
  const BasicInfoSection({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.categoryLabel,
    required this.subcategoryLabel,
    required this.subcategoryEnabled,
    required this.onCategoryTap,
    required this.onSubcategoryTap,
    required this.onNameChanged,
    required this.onDescriptionChanged,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String? categoryLabel;
  final String? subcategoryLabel;

  /// True when a category is selected AND it has at least one subcategory to
  /// pick from. Disabled state keeps the picker visible (so the field doesn't
  /// pop in unexpectedly) but greys it out so the seller knows there's
  /// nothing to choose.
  final bool subcategoryEnabled;

  final VoidCallback onCategoryTap;
  final VoidCallback onSubcategoryTap;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onDescriptionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Ma'lumotlar"),
        FormCard(
          child: Column(
            children: [
              FormTextField(
                controller: nameController,
                label: 'Mahsulot nomi',
                hint: 'Masalan, Burchakli divan «Roma»',
                onChanged: onNameChanged,
              ),
              const SizedBox(height: 14),
              PickerField(
                label: 'Kategoriya',
                value: categoryLabel,
                placeholder: 'Kategoriyani tanlang',
                leadingIcon: Iconsax.category,
                onTap: onCategoryTap,
              ),
              const SizedBox(height: 14),
              PickerField(
                label: 'Subkategoriya',
                value: subcategoryLabel,
                placeholder: subcategoryEnabled
                    ? 'Subkategoriyani tanlang (ixtiyoriy)'
                    : 'Avval kategoriya tanlang',
                leadingIcon: Iconsax.element_4,
                onTap: subcategoryEnabled ? onSubcategoryTap : null,
              ),
              const SizedBox(height: 14),
              FormTextField(
                controller: descriptionController,
                label: 'Mahsulot tavsifi',
                hint: "Mahsulot haqida qisqacha ma'lumot",
                minLines: 3,
                maxLines: 6,
                onChanged: onDescriptionChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
