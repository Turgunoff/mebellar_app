import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// Bottom bar — Archive (outlined, secondary) + Edit (filled, primary).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.onEdit});

  final VoidCallback? onEdit;

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
        border: const Border(
          top: BorderSide(color: kDivider, width: 1),
        ),
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
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Iconsax.archive_2, size: 18),
                    label: const Text(
                      'Arxivlash',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                        height: 1.0,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kInk,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: kOutline, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 7,
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(
                      Iconsax.edit_2,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Tahrirlash',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -0.1,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
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
