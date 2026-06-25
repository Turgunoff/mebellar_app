import 'package:flutter/material.dart';

import '../../../../../core/i18n/i18n.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/tariff.dart';

/// Shown in place of the form when the seller's plan quota is exhausted.
class TariffBlockedView extends StatelessWidget {
  const TariffBlockedView({super.key, required this.snapshot});

  final TariffSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: primary, size: 40),
            const SizedBox(height: 12),
            Text(
              tr('add_product.tariff_limit_reached_title'),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            if (snapshot != null) ...[
              const SizedBox(height: 6),
              Text(
                tr('add_product.products_count_line', namedArgs: {
                  'count': snapshot!.activeProductsCount.toString(),
                  'max': snapshot!.plan.isUnlimited
                      ? '∞'
                      : snapshot!.plan.maxActiveProducts.toString(),
                }),
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
