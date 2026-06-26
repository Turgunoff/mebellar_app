import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/i18n/i18n.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'form_kit.dart';
import 'thousands_formatter.dart';

/// Production time, delivery / assembly toggles and warranty fields.
class LogisticsSection extends StatelessWidget {
  const LogisticsSection({
    super.key,
    required this.productionDaysController,
    required this.deliveryAvailable,
    required this.onDeliveryChanged,
    required this.maxDeliveryFee,
    required this.onMaxDeliveryFeeChanged,
    required this.assemblyAvailable,
    required this.onAssemblyChanged,
    required this.installationPriceController,
    required this.onInstallationPriceChanged,
    required this.warrantyController,
    required this.onProductionDaysChanged,
    required this.onWarrantyChanged,
  });

  final TextEditingController productionDaysController;
  final bool deliveryAvailable;
  final ValueChanged<bool> onDeliveryChanged;

  /// Estimated maximum delivery fee (UZS), driven by the slider.
  final int maxDeliveryFee;
  final ValueChanged<int> onMaxDeliveryFeeChanged;
  final bool assemblyAvailable;
  final ValueChanged<bool> onAssemblyChanged;
  final TextEditingController installationPriceController;
  final ValueChanged<num> onInstallationPriceChanged;
  final TextEditingController warrantyController;
  final ValueChanged<String> onProductionDaysChanged;
  final ValueChanged<int> onWarrantyChanged;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(tr('add_product.section_logistics')),
        FormCard(
          child: Column(
            children: [
              FormTextField(
                controller: productionDaysController,
                label: tr('add_product.field_production_days_label'),
                hint: tr('add_product.field_production_days_hint'),
                suffix: tr('add_product.unit_days'),
                onChanged: onProductionDaysChanged,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: c.divider),
              ),
              _ToggleRow(
                icon: Iconsax.truck_fast,
                title: tr('add_product.toggle_delivery_title'),
                subtitle: tr('add_product.toggle_delivery_subtitle'),
                value: deliveryAvailable,
                onChanged: onDeliveryChanged,
              ),
              if (deliveryAvailable) ...[
                const SizedBox(height: 14),
                _MaxDeliveryFeeSlider(
                  value: maxDeliveryFee,
                  onChanged: onMaxDeliveryFeeChanged,
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: c.divider),
              ),
              _ToggleRow(
                icon: Iconsax.setting_4,
                title: tr('add_product.toggle_assembly_title'),
                subtitle: tr('add_product.toggle_assembly_subtitle'),
                value: assemblyAvailable,
                onChanged: onAssemblyChanged,
              ),
              if (assemblyAvailable) ...[
                const SizedBox(height: 14),
                FormTextField(
                  controller: installationPriceController,
                  label: tr('add_product.field_installation_price_label'),
                  hint: tr('add_product.field_price_free_hint'),
                  suffix: tr('add_product.unit_uzs'),
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsSpaceFormatter()],
                  onChanged: (v) {
                    final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                    onInstallationPriceChanged(int.tryParse(digits) ?? 0);
                  },
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: c.divider),
              ),
              FormTextField(
                controller: warrantyController,
                label: tr('add_product.field_warranty_label'),
                hint: '0',
                suffix: tr('add_product.unit_months'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => onWarrantyChanged(int.tryParse(v) ?? 0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Slider for the estimated MAXIMUM delivery fee (0 – 2,000,000 UZS, steps of
/// 50,000). The exact fee is entered by the seller per address when accepting
/// the order — this only sets the upper bound the buyer sees ("0 – max").
class _MaxDeliveryFeeSlider extends StatelessWidget {
  const _MaxDeliveryFeeSlider({required this.value, required this.onChanged});

  static const int _max = 2000000;
  static const int _step = 50000;

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final clamped = value.clamp(0, _max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr('add_product.field_max_delivery_fee_label'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.grey,
                letterSpacing: 0.1,
              ),
            ),
            Text(
              clamped == 0
                  ? tr('add_product.field_price_free_hint')
                  : '${_formatThousands(clamped)} ${tr('add_product.unit_uzs')}',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: primary,
            thumbColor: primary,
            overlayColor: primary.withValues(alpha: 0.12),
            inactiveTrackColor: c.fillFaint,
          ),
          child: Slider(
            value: clamped.toDouble(),
            max: _max.toDouble(),
            divisions: _max ~/ _step,
            label: _formatThousands(clamped),
            onChanged: (v) => onChanged((v / _step).round() * _step),
          ),
        ),
        Text(
          tr('add_product.field_max_delivery_fee_helper'),
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: c.greyMid,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  static String _formatThousands(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: c.grey,
                ),
              ),
            ],
          ),
        ),
        CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: primary,
        ),
      ],
    );
  }
}
