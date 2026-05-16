import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'order_details_kit.dart';

/// Sticky bottom action bar — Reject (outline) on the left, Accept (filled
/// terracotta) on the right with a wider flex so the primary action
/// visually dominates.
///
/// Sprint B.1 wires [onReject] / [onAccept] (and the later shipped/delivered
/// transitions) to `SupabaseSellerOrderRepository`.
class OrderActionBar extends StatelessWidget {
  const OrderActionBar({super.key, this.onReject, this.onAccept});

  final VoidCallback? onReject;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(top: BorderSide(color: kDivider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: onReject ?? () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kInk,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: kOutline, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Rad etish',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 7,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: onAccept ?? () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.tick_circle,
                            size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Buyurtmani qabul qilish',
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.0,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
