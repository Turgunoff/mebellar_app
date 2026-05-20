import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Yetkazib berish va kafolat'),
        FormCard(
          child: Column(
            children: [
              FormTextField(
                controller: productionDaysController,
                label: 'Tayyorlash / Yetkazish muddati (kun)',
                hint: '3-5',
                suffix: 'kun',
                onChanged: onProductionDaysChanged,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: kDivider),
              ),
              _ToggleRow(
                icon: Iconsax.truck_fast,
                title: 'Yetkazib berish mavjud',
                subtitle: 'Sotib oluvchiga yetkazib beriladi',
                value: deliveryAvailable,
                onChanged: onDeliveryChanged,
              ),
              if (deliveryAvailable) ...[
                const SizedBox(height: 14),
                FormTextField(
                  controller: deliveryPriceController,
                  label: 'Toshkent ichida yetkazish narxi',
                  hint: 'Bepul uchun 0 kiriting',
                  suffix: 'UZS',
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsSpaceFormatter()],
                  helper:
                      'Hozircha faqat Toshkent shahri va viloyati. Boshqa viloyatlar '
                      'keyinroq qo‘shiladi.',
                  onChanged: (v) {
                    final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                    onDeliveryPriceChanged(int.tryParse(digits) ?? 0);
                  },
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: kDivider),
              ),
              _ToggleRow(
                icon: Iconsax.setting_4,
                title: "O'rnatib berish mavjud",
                subtitle: "Mahsulot xaridor manzilida yig'iladi",
                value: assemblyAvailable,
                onChanged: onAssemblyChanged,
              ),
              if (assemblyAvailable) ...[
                const SizedBox(height: 14),
                FormTextField(
                  controller: installationPriceController,
                  label: "O'rnatish narxi",
                  hint: 'Bepul uchun 0 kiriting',
                  suffix: 'UZS',
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsSpaceFormatter()],
                  onChanged: (v) {
                    final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                    onInstallationPriceChanged(int.tryParse(digits) ?? 0);
                  },
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: kDivider),
              ),
              FormTextField(
                controller: warrantyController,
                label: 'Kafolat (oy)',
                hint: '0',
                suffix: 'oy',
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
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kGrey,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: primary,
        ),
      ],
    );
  }
}
