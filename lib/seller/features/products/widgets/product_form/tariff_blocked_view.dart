import 'package:flutter/material.dart';

import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/tariff.dart';
import 'form_kit.dart';

/// Shown in place of the form when the seller's plan quota is exhausted.
class TariffBlockedView extends StatelessWidget {
  const TariffBlockedView({super.key, required this.snapshot});

  final TariffSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: primary, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Tarif chegarasi tugadi',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
            ),
            if (snapshot != null) ...[
              const SizedBox(height: 6),
              Text(
                'Mahsulotlar: ${snapshot!.activeProductsCount} / '
                '${snapshot!.plan.isUnlimited ? '∞' : snapshot!.plan.maxActiveProducts}',
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kGrey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
