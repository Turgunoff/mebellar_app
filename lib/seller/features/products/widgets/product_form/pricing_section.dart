import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../bloc/add_product_cubit.dart';
import 'form_kit.dart';
import 'thousands_formatter.dart';

/// Base price (with a UZS|USD currency toggle), discount-percent chips and
/// the discounted-price summary. USD is an input convenience only — every
/// derived figure shown here is UZS, converted with the CBU [usdRate].
class PricingSection extends StatelessWidget {
  const PricingSection({
    super.key,
    required this.priceController,
    required this.currency,
    required this.usdRate,
    required this.discountPercent,
    required this.priceValue,
    required this.uzsPrice,
    required this.discountedUzsPrice,
    required this.onPriceChanged,
    required this.onCurrencyChanged,
    required this.onDiscountSelected,
    required this.onCustomTapped,
  });

  final TextEditingController priceController;
  final PriceCurrency currency;

  /// CBU USD→UZS rate; null while loading/unavailable — the USD segment is
  /// rendered dimmed (tapping it retries the fetch via the cubit).
  final double? usdRate;
  final int discountPercent;

  /// Raw typed number, in [currency].
  final int priceValue;

  /// Base price converted to UZS (equals [priceValue] for UZS input).
  final int uzsPrice;

  /// Discounted price in UZS — what the summary box leads with.
  final int discountedUzsPrice;
  final ValueChanged<num> onPriceChanged;
  final ValueChanged<PriceCurrency> onCurrencyChanged;
  final ValueChanged<int> onDiscountSelected;
  final VoidCallback onCustomTapped;

  bool get _isUsd => currency == PriceCurrency.usd;

  String? _helperText() {
    final rate = usdRate;
    if (!_isUsd || rate == null) return null;
    final rateLabel = '1 USD = ${formatThousands(rate.round())} UZS';
    if (priceValue <= 0) return '$rateLabel (MB kursi)';
    return '≈ ${formatThousands(uzsPrice)} UZS · $rateLabel';
  }

  /// Discounted total back in USD for the summary's secondary line, so the
  /// seller can sanity-check the UZS figure against what they typed.
  String? _usdSecondary() {
    if (!_isUsd || priceValue <= 0) return null;
    final discounted = discountPercent > 0
        ? priceValue * (100 - discountPercent) / 100
        : priceValue.toDouble();
    return '≈ ${formatThousands(discounted.round())} USD';
  }

  /// The cubit refuses to switch to USD until a rate exists (and retries the
  /// fetch on that tap) — without feedback the dimmed segment would feel
  /// dead, so explain why nothing switched.
  void _handleCurrencyTap(BuildContext context, PriceCurrency next) {
    if (next == PriceCurrency.usd && usdRate == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
            content: Text(
              "Dollar kursi hali yuklanmadi — birozdan so'ng qayta urinib "
              "ko'ring.",
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        );
    }
    onCurrencyChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
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
                suffixWidget: _CurrencyToggle(
                  value: currency,
                  usdEnabled: usdRate != null,
                  onChanged: (next) => _handleCurrencyTap(context, next),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsSpaceFormatter()],
                helper: _helperText(),
                helperColor: priceValue > 0 ? primary : null,
                onChanged: (v) {
                  final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                  onPriceChanged(int.tryParse(digits) ?? 0);
                },
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  'Chegirma foizi',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.grey,
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
                hasPrice: priceValue > 0 && uzsPrice > 0,
                discountPercent: discountPercent,
                discountedUzsPrice: discountedUzsPrice,
                secondary: _usdSecondary(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact two-segment UZS|USD pill living in the price field's suffix.
class _CurrencyToggle extends StatelessWidget {
  const _CurrencyToggle({
    required this.value,
    required this.usdEnabled,
    required this.onChanged,
  });

  final PriceCurrency value;

  /// False until the CBU rate loads — the USD segment renders dimmed, but
  /// stays tappable so the tap can retry the fetch (the cubit won't switch
  /// without a rate).
  final bool usdEnabled;
  final ValueChanged<PriceCurrency> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.fillFaint,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.outline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CurrencySegment(
            label: 'UZS',
            selected: value == PriceCurrency.uzs,
            dimmed: false,
            onTap: () => onChanged(PriceCurrency.uzs),
          ),
          _CurrencySegment(
            label: 'USD',
            selected: value == PriceCurrency.usd,
            dimmed: !usdEnabled,
            onTap: () => onChanged(PriceCurrency.usd),
          ),
        ],
      ),
    );
  }
}

class _CurrencySegment extends StatelessWidget {
  const _CurrencySegment({
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final Color textColor;
    if (selected) {
      textColor = Colors.white;
    } else if (dimmed) {
      textColor = c.greyMid.withValues(alpha: 0.45);
    } else {
      textColor = c.grey;
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: 0.3,
          ),
        ),
      ),
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
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary : c.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? primary : c.outline, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : c.ink,
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
    required this.hasPrice,
    required this.discountPercent,
    required this.discountedUzsPrice,
    this.secondary,
  });

  final bool hasPrice;
  final int discountPercent;

  /// Final (discounted) price in UZS — always the primary figure, whatever
  /// currency the seller typed in.
  final int discountedUzsPrice;

  /// Optional USD echo of the same total when the input currency is USD.
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final hasDiscount = discountPercent > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasPrice && hasDiscount
            ? primary.withValues(alpha: 0.08)
            : c.fillFaint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPrice && hasDiscount
              ? primary.withValues(alpha: 0.35)
              : c.outline,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasDiscount ? Iconsax.discount_shape : Iconsax.tag,
            size: 18,
            color: hasPrice && hasDiscount ? primary : c.greyMid,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDiscount ? 'Chegirma bilan' : 'Chegirmasiz',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.grey,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPrice
                      ? '${formatThousands(discountedUzsPrice)} UZS'
                      : '— UZS',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: hasPrice && hasDiscount ? primary : c.ink,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                ),
                if (hasPrice && secondary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary!,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.grey,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasDiscount && hasPrice)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
