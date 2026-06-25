import 'package:flutter/material.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';

/// Locked, greyed-out variant of the seller AR card shown when a product hasn't
/// cleared moderation. AR generation costs a token + a (paid) Meshy task, so it
/// is gated to approved products only — this surfaces *why* the scan controls
/// are unavailable instead of hiding the feature silently. Backend enforces the
/// same rule (`POST /ar-scan/photos` → 403 `product_not_approved`).
class ArNotApprovedCard extends StatelessWidget {
  const ArNotApprovedCard({super.key});

  static String get message => tr('seller.ar_not_approved_message');

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.fillFaint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.lock_outline, color: c.grey, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('seller.ar_scan_card_title'),
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: c.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 12.5,
                      color: c.grey,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
