import 'package:flutter/material.dart';

import '../../../../../core/theme/app_fonts.dart';
import '../../bloc/add_product_cubit.dart';
import 'form_kit.dart';

/// Variant-level data section. Today the only per-product variant axis is
/// colour — the form supports **multi-select** so one product can ship in
/// several colours. The chosen slugs persist to `products.colors text[]`;
/// `product_variants.color_name` keeps the first selected label for any
/// downstream consumer that still expects a single value.
///
/// Lives in its own widget so a future full multi-variant UI (color × size
/// → per-variant SKU/price) can grow here without touching the dynamic
/// schema engine.
class VariantSection extends StatelessWidget {
  const VariantSection({
    super.key,
    required this.selectedColors,
    required this.onColorToggle,
  });

  final Set<String> selectedColors;
  final ValueChanged<String> onColorToggle;

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
                  'Ranglar',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kGrey,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 10),
                child: Text(
                  'Bir nechtasini tanlash mumkin',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: kGreyMid,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in kAddProductColorOptions)
                    _ColorChip(
                      label: c.label,
                      swatch: Color(c.swatch),
                      selected: selectedColors.contains(c.slug),
                      onTap: () => onColorToggle(c.slug),
                    ),
                ],
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
              _Swatch(color: swatch, checked: selected),
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

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.checked});

  final Color color;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // Pick a contrasting tick icon depending on the swatch brightness so the
    // check stays visible against both light (e.g. white) and dark fills.
    final tickColor = color.computeLuminance() > 0.6 ? primary : Colors.white;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: kOutline, width: 1),
      ),
      alignment: Alignment.center,
      child: checked
          ? Icon(Icons.check_rounded, size: 12, color: tickColor)
          : null,
    );
  }
}
