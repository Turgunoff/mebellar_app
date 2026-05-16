import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_fonts.dart';
import '../../bloc/add_product_cubit.dart';
import 'form_kit.dart';

/// Dimensions, material and colour fields.
class SpecsSection extends StatelessWidget {
  const SpecsSection({
    super.key,
    required this.widthController,
    required this.heightController,
    required this.depthController,
    required this.materialController,
    required this.selectedColor,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onDepthChanged,
    required this.onMaterialChanged,
    required this.onColorToggle,
  });

  final TextEditingController widthController;
  final TextEditingController heightController;
  final TextEditingController depthController;
  final TextEditingController materialController;
  final String? selectedColor;
  final ValueChanged<int?> onWidthChanged;
  final ValueChanged<int?> onHeightChanged;
  final ValueChanged<int?> onDepthChanged;
  final ValueChanged<String> onMaterialChanged;
  final ValueChanged<String?> onColorToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Xususiyatlar'),
        FormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  "O'lchamlari (sm)",
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kGrey,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _DimensionField(
                      controller: widthController,
                      label: 'Eni',
                      onChanged: (v) => onWidthChanged(int.tryParse(v)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DimensionField(
                      controller: heightController,
                      label: "Bo'yi",
                      onChanged: (v) => onHeightChanged(int.tryParse(v)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DimensionField(
                      controller: depthController,
                      label: 'Chuqurligi',
                      onChanged: (v) => onDepthChanged(int.tryParse(v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FormTextField(
                controller: materialController,
                label: 'Material',
                hint: "MDF, LDSP, Yog'och",
                onChanged: onMaterialChanged,
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
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

class _DimensionField extends StatelessWidget {
  const _DimensionField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kOutline),
    );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      cursorColor: primary,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: AppFonts.seller,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: kInk,
        letterSpacing: -0.1,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
        hintText: label,
        hintStyle: const TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: kGreyMid,
        ),
        filled: true,
        fillColor: Colors.white,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
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
