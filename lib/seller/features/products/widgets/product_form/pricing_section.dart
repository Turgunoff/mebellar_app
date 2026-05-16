import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'form_kit.dart';
import 'thousands_formatter.dart';

/// Base price, discount-percent chips and the discounted-price summary.
class PricingSection extends StatelessWidget {
  const PricingSection({
    super.key,
    required this.priceController,
    required this.discountPercent,
    required this.priceValue,
    required this.discountedPrice,
    required this.onPriceChanged,
    required this.onDiscountSelected,
    required this.onCustomTapped,
  });

  final TextEditingController priceController;
  final int discountPercent;
  final int priceValue;
  final int discountedPrice;
  final ValueChanged<num> onPriceChanged;
  final ValueChanged<int> onDiscountSelected;
  final VoidCallback onCustomTapped;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Narx va chegirma'),
        FormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormTextField(
                controller: priceController,
                label: 'Asosiy narx',
                hint: '0',
                suffix: 'UZS',
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsSpaceFormatter()],
                onChanged: (v) {
                  final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                  onPriceChanged(int.tryParse(digits) ?? 0);
                },
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  'Chegirma foizi',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kGrey,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              _DiscountChipRow(
                value: discountPercent,
                onSelected: onDiscountSelected,
                onCustomTapped: onCustomTapped,
              ),
              const SizedBox(height: 14),
              _DiscountSummary(
                priceValue: priceValue,
                discountPercent: discountPercent,
                discountedPrice: discountedPrice,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscountChipRow extends StatelessWidget {
  const _DiscountChipRow({
    required this.value,
    required this.onSelected,
    required this.onCustomTapped,
  });

  final int value;
  final ValueChanged<int> onSelected;
  final VoidCallback onCustomTapped;

  static const _presets = [0, 10, 20, 30];

  @override
  Widget build(BuildContext context) {
    final isCustom = !_presets.contains(value);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in _presets)
          _DiscountChip(
            label: '$p%',
            selected: !isCustom && value == p,
            onTap: () => onSelected(p),
          ),
        _DiscountChip(
          label: isCustom ? '$value% (Custom)' : 'Custom',
          selected: isCustom,
          onTap: onCustomTapped,
        ),
      ],
    );
  }
}

class _DiscountChip extends StatelessWidget {
  const _DiscountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? primary : kOutline,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : kInk,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscountSummary extends StatelessWidget {
  const _DiscountSummary({
    required this.priceValue,
    required this.discountPercent,
    required this.discountedPrice,
  });

  final int priceValue;
  final int discountPercent;
  final int discountedPrice;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasPrice = priceValue > 0;
    final hasDiscount = discountPercent > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasPrice && hasDiscount
            ? primary.withValues(alpha: 0.08)
            : kFillSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPrice && hasDiscount
              ? primary.withValues(alpha: 0.35)
              : kOutline,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasDiscount ? Iconsax.discount_shape : Iconsax.tag,
            size: 18,
            color: hasPrice && hasDiscount ? primary : kGreyMid,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDiscount ? 'Chegirma bilan' : 'Chegirmasiz',
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kGrey,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPrice
                      ? '${formatThousands(discountedPrice)} UZS'
                      : '— UZS',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: hasPrice && hasDiscount ? primary : kInk,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (hasDiscount && hasPrice)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-$discountPercent%',
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
