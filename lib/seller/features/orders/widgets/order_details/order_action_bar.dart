import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/order_status.dart';
import '../../../../../shared/repositories/seller_order_repository.dart';
import '../order_format.dart';
import 'order_details_kit.dart';

/// Sticky bottom action bar for the seller order-detail screen.
///
/// Driven entirely by [status]: it surfaces the next legal forward
/// transition (`pending → confirmed → preparing → shipped → delivered`) as the
/// primary action and a Cancel button while the order is still cancellable.
/// A terminal order (delivered / cancelled) collapses the bar away.
class OrderActionBar extends StatelessWidget {
  const OrderActionBar({
    super.key,
    required this.status,
    required this.busy,
    required this.onTransition,
    required this.onCancel,
    this.feePendingCustomer = false,
  });

  final OrderStatus status;

  /// True while a transition is in flight — disables every button.
  final bool busy;

  /// Dispatched with the target status of the next forward transition.
  final void Function(OrderStatus target) onTransition;
  final VoidCallback onCancel;

  /// When true the primary CTA is replaced with a "waiting" message while
  /// the customer reviews the proposed delivery fee.
  final bool feePendingCustomer;

  @override
  Widget build(BuildContext context) {
    final forward = status.sellerForwardTransitions;
    // Terminal order — nothing left for the seller to do.
    if (forward.isEmpty) return const SizedBox.shrink();

    if (feePendingCustomer) {
      return _WaitingForCustomerBar(canCancel: status.cancellable, onCancel: onCancel);
    }

    final target = forward.first;
    final canCancel = status.cancellable;

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
              if (canCancel) ...[
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: busy ? null : onCancel,
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
                        'Bekor qilish',
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
              ],
              Expanded(
                flex: 7,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: busy ? null : () => onTransition(target),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.terracotta.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Iconsax.tick_circle,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  sellerOrderActionLabel(target),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: AppFonts.seller,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.0,
                                    letterSpacing: -0.1,
                                  ),
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

class _WaitingForCustomerBar extends StatelessWidget {
  const _WaitingForCustomerBar({
    required this.canCancel,
    required this.onCancel,
  });

  final bool canCancel;
  final VoidCallback onCancel;

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
              if (canCancel) ...[
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kInk,
                        side: const BorderSide(color: kOutline, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Bekor qilish',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kInk,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 6,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EE),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: const Color(0xFFFFD580), width: 1),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hourglass_bottom_rounded,
                        size: 16,
                        color: Color(0xFF8C5A12),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Mijoz tasdiqlashini kutmoqda',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8C5A12),
                          ),
                        ),
                      ),
                    ],
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
