import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'settings_form_kit.dart';

/// Brand colour swatch + map-picked shop address.
///
/// The free-text address field (and the older region/city/district picker)
/// were replaced by a map trigger: tapping the address row opens the same
/// Yandex map picker the onboarding flow uses, so the seller drops a pin and
/// the geocoded address + lat/lng are written together.
class BrandLocationCard extends StatelessWidget {
  const BrandLocationCard({
    super.key,
    required this.brandHex,
    required this.brandColor,
    required this.onPickColor,
    required this.address,
    required this.onPickAddress,
  });

  final String? brandHex;
  final Color? brandColor;
  final VoidCallback onPickColor;
  final String address;
  final VoidCallback onPickAddress;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final hasAddress = address.trim().isNotEmpty;
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
                    color: brandColor ?? AppColors.sellerPrimary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.outline, width: 1),
                  ),
                ),
                title: tr('shop_settings.brand_color'),
                subtitle: brandHex ?? '#5E35B1',
                trailing: Icon(Iconsax.colorfilter, size: 18, color: c.greyMid),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: c.divider),
              ),
              _ListRow(
                onTap: onPickAddress,
                leading: const IconTile(icon: Iconsax.location),
                title: tr('shop_settings.address_title'),
                subtitle: hasAddress
                    ? address.trim()
                    : tr('shop_settings.address_empty'),
                trailing: Icon(Iconsax.map_1, size: 18, color: c.greyMid),
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
    final c = SellerColors.of(context);
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
