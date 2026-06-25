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
    required this.deliveryPriceController,
    required this.assemblyAvailable,
    required this.onAssemblyChanged,
    required this.installationPriceController,
    required this.onInstallationPriceChanged,
    required this.warrantyController,
    required this.onProductionDaysChanged,
    required this.onDeliveryPriceChanged,
    required this.onWarrantyChanged,
  });

  final TextEditingController productionDaysController;
  final bool deliveryAvailable;
  final ValueChanged<bool> onDeliveryChanged;
  final TextEditingController deliveryPriceController;
  final bool assemblyAvailable;
  final ValueChanged<bool> onAssemblyChanged;
  final TextEditingController installationPriceController;
  final ValueChanged<num> onInstallationPriceChanged;
  final TextEditingController warrantyController;
  final ValueChanged<String> onProductionDaysChanged;
  final ValueChanged<num> onDeliveryPriceChanged;
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
                FormTextField(
                  controller: deliveryPriceController,
                  label: tr('add_product.field_delivery_price_label'),
                  hint: tr('add_product.field_price_free_hint'),
                  suffix: tr('add_product.unit_uzs'),
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsSpaceFormatter()],
                  helper: tr('add_product.field_delivery_price_helper'),
                  onChanged: (v) {
                    final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                    onDeliveryPriceChanged(int.tryParse(digits) ?? 0);
                  },
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
