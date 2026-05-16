import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'order_details_kit.dart';

/// Order id, placed-at date and status pill — sits above the timeline so the
/// header info is glanceable without scrolling into the tracker.
class OrderMetaCard extends StatelessWidget {
  const OrderMetaCard({
    super.key,
    required this.orderId,
    required this.date,
    required this.statusLabel,
    this.statusBg = kAmberBg,
    this.statusFg = kAmberFg,
  });

  final String orderId;
  final String date;
  final String statusLabel;

  /// Status-pill colours — default to amber (pending); the detail screen
  /// passes the colours matching the live order status.
  final Color statusBg;
  final Color statusFg;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$orderId',
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Iconsax.calendar_1, size: 14, color: kGrey),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: const TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: kGrey,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusFg,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
