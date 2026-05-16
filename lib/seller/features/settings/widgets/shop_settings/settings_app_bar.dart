import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'settings_form_kit.dart';

/// App bar for the shop-settings screen — back arrow + bold title.
class ShopSettingsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ShopSettingsAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.lightBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: kInk,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left_2, size: 22, color: kInk),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        tr('shop_settings.title'),
        style: const TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: kInk,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
