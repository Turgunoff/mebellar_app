import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/i18n/i18n.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'order_details_kit.dart';

/// Horizontal order-status stepper. Completed = filled indigo with a
/// white check; current = ring; upcoming = grey. Connectors trail the last
/// completed step so progress reads at-a-glance.
class StatusTimelineCard extends StatelessWidget {
  const StatusTimelineCard({super.key, required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final steps = <String>[
      tr('seller_orders.timeline_created'),
      tr('seller_orders.timeline_accepted'),
      tr('seller_orders.action_preparing'),
      tr('seller_orders.order_status_shipped'),
      tr('seller_orders.action_delivered'),
    ];
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(text: tr('seller_orders.timeline_title')),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(steps.length, (i) {
                  final isCompleted = i < currentStep;
                  final isCurrent = i == currentStep;
                  final isLast = i == steps.length - 1;
                  return Expanded(
                    child: _TimelineNode(
                      label: steps[i],
                      isCompleted: isCompleted,
                      isCurrent: isCurrent,
                      showTrailingConnector: !isLast,
                      trailingConnectorActive: i < currentStep,
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    required this.showTrailingConnector,
    required this.trailingConnectorActive,
  });

  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final bool showTrailingConnector;
  final bool trailingConnectorActive;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    const activeColor = AppColors.sellerPrimary;
    final inactiveDot = c.fillSoft;
    final inactiveBorder = c.outline;
    const connectorActive = AppColors.sellerPrimary;
    final connectorInactive = c.dividerStrong;

    Widget dot;
    if (isCompleted) {
      dot = Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          color: activeColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Iconsax.tick_circle, size: 16, color: Colors.white),
      );
    } else if (isCurrent) {
      dot = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: c.primarySoft,
          shape: BoxShape.circle,
          border: Border.all(color: activeColor, width: 2),
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else {
      dot = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: inactiveDot,
          shape: BoxShape.circle,
          border: Border.all(color: inactiveBorder, width: 1),
        ),
      );
    }

    final labelColor = isCompleted || isCurrent ? c.ink : c.greySoft;
    final labelWeight = isCurrent
        ? FontWeight.w700
        : (isCompleted ? FontWeight.w600 : FontWeight.w500);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Left half-connector — keeps the dot centered under the label;
            // transparent so the first node has no leading line.
            Expanded(child: Container(height: 2, color: Colors.transparent)),
            dot,
            Expanded(
              child: Container(
                height: 2,
                color: showTrailingConnector
                    ? (trailingConnectorActive
                          ? connectorActive
                          : connectorInactive)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 10.5,
            fontWeight: labelWeight,
            color: labelColor,
            height: 1.25,
            letterSpacing: -0.05,
          ),
        ),
      ],
    );
  }
}
