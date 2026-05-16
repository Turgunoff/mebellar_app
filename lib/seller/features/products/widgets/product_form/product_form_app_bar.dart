import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'form_kit.dart';

/// App bar for the product form screen.
class ProductFormAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ProductFormAppBar({super.key});

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
      title: const Text(
        "Mahsulot qo'shish",
        style: TextStyle(
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
