import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/i18n/i18n.dart';
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
        SectionTitle(tr('add_product.section_basic_info')),
        FormCard(
          child: Column(
            children: [
              FormTextField(
                controller: nameController,
                label: tr('add_product.field_name_label'),
                hint: tr('add_product.field_name_hint'),
                onChanged: onNameChanged,
              ),
              const SizedBox(height: 14),
              PickerField(
                label: tr('add_product.field_category_label'),
                value: categoryLabel,
                placeholder: tr('add_product.field_category_placeholder'),
                leadingIcon: Iconsax.category,
                onTap: onCategoryTap,
              ),
              const SizedBox(height: 14),
              PickerField(
                label: tr('add_product.field_subcategory_label'),
                value: subcategoryLabel,
                placeholder: subcategoryEnabled
                    ? tr('add_product.field_subcategory_placeholder')
                    : tr('add_product.field_subcategory_placeholder_disabled'),
                leadingIcon: Iconsax.element_4,
                onTap: subcategoryEnabled ? onSubcategoryTap : null,
              ),
              const SizedBox(height: 14),
              FormTextField(
                controller: descriptionController,
                label: tr('add_product.field_description_label'),
                hint: tr('add_product.field_description_hint'),
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
