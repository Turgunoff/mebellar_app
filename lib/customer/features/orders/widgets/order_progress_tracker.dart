import 'package:flutter/material.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../home/widgets/premium/premium_tokens.dart';

/// Premium horizontal lifecycle tracker for the orders list card.
///
/// Steps: Payment → Confirmed → Prep → Transit → Delivered.
/// Completed nodes: brand-filled circle + white check.
/// Active node: larger filled circle with a soft outer ring.
/// Upcoming: quiet light-grey dots; labels recede except the active one.
class OrderProgressTracker extends StatelessWidget {
  const OrderProgressTracker({super.key, required this.status});

  final String status;

  static const _upcoming = Color(0xFFD1D5DB);
  static const _upcomingLabel = Color(0xFFB0B5BD);
  static const _nodeSize = 20.0;
  static const _lineHeight = 2.5;

  /// Index of the active step, or `-1` when the order is cancelled / unknown.
  static int activeIndexFor(String status) {
    return switch (status) {
      'awaiting_payment' || 'pending' => 0,
      'confirmed' => 1,
      'preparing' => 2,
      'shipped' => 3,
      'delivered' => 4,
      _ => -1,
    };
  }

  @override
  Widget build(BuildContext context) {
    final active = activeIndexFor(status);
    if (active < 0) return const SizedBox.shrink();

    final labels = [
      tr('orders.tracker_payment'),
      tr('orders.tracker_confirmed'),
      tr('orders.tracker_preparing'),
      tr('orders.tracker_shipped'),
      tr('orders.tracker_delivered'),
    ];

    final pt = PremiumTokens.of(context);
    const brand = PremiumTokens.accent;

    return Column(
      children: [
        SizedBox(
          height: _nodeSize + 4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: _lineHeight,
                      decoration: BoxDecoration(
                        color: i <= active ? brand : _upcoming,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                _Node(index: i, active: active, brand: brand),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumTokens.body(
                    size: i == active ? 10.5 : 9.5,
                    weight: i == active ? FontWeight.w700 : FontWeight.w500,
                    color: i == active
                        ? pt.dark
                        : i < active
                        ? brand.withValues(alpha: 0.85)
                        : _upcomingLabel,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({
    required this.index,
    required this.active,
    required this.brand,
  });

  final int index;
  final int active;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    // Completed — brand fill + white check.
    if (index < active) {
      return Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: brand,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
      );
    }

    // Active — larger node with soft outer ring / glow.
    if (index == active) {
      final isTerminal = active == 4;
      return Container(
        width: OrderProgressTracker._nodeSize,
        height: OrderProgressTracker._nodeSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: brand.withValues(alpha: 0.14),
          border: Border.all(color: brand.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: brand,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: brand.withValues(alpha: 0.35),
                blurRadius: 6,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Icon(
            isTerminal ? Icons.check_rounded : Icons.circle,
            size: isTerminal ? 10 : 5,
            color: Colors.white,
          ),
        ),
      );
    }

    // Upcoming — quiet solid grey dot.
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: OrderProgressTracker._upcoming,
        shape: BoxShape.circle,
      ),
    );
  }
}
