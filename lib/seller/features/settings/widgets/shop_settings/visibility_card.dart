import 'package:flutter/cupertino.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'settings_form_kit.dart';

/// Public / hidden shop-visibility toggle.
class VisibilityCard extends StatelessWidget {
  const VisibilityCard({
    super.key,
    required this.isPublic,
    required this.onChanged,
  });

  final bool isPublic;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(tr('shop_settings.visibility_title')),
        SettingsCard(
          child: Row(
            children: [
              IconTile(icon: isPublic ? Iconsax.eye : Iconsax.eye_slash),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        isPublic
                            ? 'shop_settings.public'
                            : 'shop_settings.hidden',
                      ),
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
                      tr(
                        isPublic
                            ? 'shop_settings.public_hint'
                            : 'shop_settings.hidden_hint',
                      ),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.grey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: isPublic,
                onChanged: onChanged,
                activeTrackColor: AppColors.sellerPrimary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
