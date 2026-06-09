import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// Bottom bar — secondary action (Archive, or Restore when the product is
/// already archived) + Edit (filled, primary). The secondary action is hidden
/// when its callback is null.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.onEdit,
    this.onArchive,
    this.onRestore,
    this.isArchived = false,
    this.isBusy = false,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  /// When true the product is archived, so the secondary action restores it
  /// (indigo "Qaytarish") instead of archiving it (neutral "Arxivlash").
  final bool isArchived;

  /// Disables both actions and shows a spinner on the secondary one while a
  /// mutation is in flight, so a double-tap can't fire two requests.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final secondaryOnPressed = isArchived ? onRestore : onArchive;
    final hasSecondary = secondaryOnPressed != null;
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
              if (hasSecondary) ...[
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: isBusy ? null : secondaryOnPressed,
                      icon: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(kGrey),
                              ),
                            )
                          : Icon(
                              isArchived
                                  ? Iconsax.refresh_2
                                  : Iconsax.archive_2,
                              size: 18,
                              color: isArchived
                                  ? AppColors.sellerPrimary
                                  : kInk,
                            ),
                      label: Text(
                        isArchived ? 'Qaytarish' : 'Arxivlash',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isArchived ? AppColors.sellerPrimary : kInk,
                          height: 1.0,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isArchived
                            ? AppColors.sellerPrimary
                            : kInk,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isArchived
                              ? AppColors.sellerPrimary.withValues(alpha: 0.4)
                              : kOutline,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
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
                      backgroundColor: AppColors.sellerPrimary,
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
