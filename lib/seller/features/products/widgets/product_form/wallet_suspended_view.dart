import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../wallet/screens/wallet_screen.dart';

/// Shown in place of the add-product form while the shop is frozen for
/// unpaid debt. Upgrading the tariff wouldn't help — only clearing the
/// balance does, so the single CTA leads to the wallet.
class WalletSuspendedView extends StatelessWidget {
  const WalletSuspendedView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.lock, color: AppColors.danger, size: 40),
            const SizedBox(height: 12),
            Text(
              "Do'koningiz vaqtincha muzlatildi",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Qarzdorlik uzilmaguncha yangi mahsulot qo'shib bo'lmaydi. "
              "Hisobni to'ldirishingiz bilan do'kon avtomatik tiklanadi.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: c.grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Qarzdorlikni uzish',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
