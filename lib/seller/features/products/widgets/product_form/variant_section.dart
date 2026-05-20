import 'package:flutter/material.dart';

import '../../../../../core/theme/app_fonts.dart';
import '../../bloc/add_product_cubit.dart';
import 'form_kit.dart';

/// Variant-level data section. Today only color is collected per variant; the
/// section sits between the dynamic category attributes (product-level) and
/// pricing so the visual grouping mirrors how the data is stored: dynamic
/// `attributes` JSONB on the product row vs. `color_name` on the variant row.
///
/// Lives in its own widget so multi-variant UI (e.g. one product → 3 colors)
/// can drop in here without touching the dynamic schema engine.
class VariantSection extends StatelessWidget {
  const VariantSection({
    super.key,
    required this.selectedColor,
    required this.onColorToggle,
  });

  final String? selectedColor;
  final ValueChanged<String?> onColorToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Variant'),
        FormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 8),
                child: Text(
                  'Rangi',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kGrey,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kAddProductColorOptions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = kAddProductColorOptions[i];
                    return _ColorChip(
                      label: c.label,
                      swatch: Color(c.swatch),
                      selected: selectedColor == c.slug,
                      onTap: () => onColorToggle(c.slug),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.label,
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color swatch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tint = primary.withValues(alpha: 0.08);
    return Material(
      color: selected ? tint : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? primary : kOutline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: kOutline, width: 1),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? primary : kInk,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
