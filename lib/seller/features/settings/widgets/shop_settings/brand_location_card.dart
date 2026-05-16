import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'settings_form_kit.dart';

/// Brand colour swatch + region picker + street field.
class BrandLocationCard extends StatelessWidget {
  const BrandLocationCard({
    super.key,
    required this.brandHex,
    required this.brandColor,
    required this.onPickColor,
    required this.regionLabel,
    required this.citySublabel,
    required this.onPickRegion,
    required this.streetController,
    required this.onStreetChanged,
  });

  final String? brandHex;
  final Color? brandColor;
  final VoidCallback onPickColor;
  final String regionLabel;
  final String citySublabel;
  final VoidCallback onPickRegion;
  final TextEditingController streetController;
  final VoidCallback onStreetChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(tr('shop_settings.brand_color')),
        SettingsCard(
          child: Column(
            children: [
              _ListRow(
                onTap: onPickColor,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: brandColor ?? AppColors.terracotta,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kOutline, width: 1),
                  ),
                ),
                title: tr('shop_settings.brand_color'),
                subtitle: brandHex ?? '#5E35B1',
                trailing: const Icon(
                  Iconsax.colorfilter,
                  size: 18,
                  color: kGreyMid,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: kDivider),
              ),
              _ListRow(
                onTap: onPickRegion,
                leading: const IconTile(icon: Iconsax.location),
                title: regionLabel,
                subtitle: citySublabel.isEmpty ? '—' : citySublabel,
                trailing: const Icon(
                  Iconsax.arrow_right_3,
                  size: 18,
                  color: kGreyMid,
                ),
              ),
              const SizedBox(height: 14),
              SettingsTextField(
                controller: streetController,
                label: tr('address.street'),
                hint: "Ko'cha, uy raqami yoki mo'ljal",
                onChanged: (_) => onStreetChanged(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
