import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'order_details_kit.dart';

/// Horizontal order-status stepper. Completed = filled terracotta with a
/// white check; current = ring; upcoming = grey. Connectors trail the last
/// completed step so progress reads at-a-glance.
class StatusTimelineCard extends StatelessWidget {
  const StatusTimelineCard({super.key, required this.currentStep});

  final int currentStep;

  static const _steps = <String>[
    'Yaratildi',
    'Qabul qilindi',
    'Tayyorlanmoqda',
    "Yo'lda",
    'Yetkazildi',
  ];

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: 'Buyurtma holati'),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(_steps.length, (i) {
                  final isCompleted = i < currentStep;
                  final isCurrent = i == currentStep;
                  final isLast = i == _steps.length - 1;
                  return Expanded(
                    child: _TimelineNode(
                      label: _steps[i],
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
    const activeColor = AppColors.terracotta;
    const inactiveDot = kSurfaceMuted;
    const inactiveBorder = kOutline;
    const connectorActive = AppColors.terracotta;
    const connectorInactive = kDivider;

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
          color: kTerracottaSoft,
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

    final labelColor = isCompleted || isCurrent ? kInk : kGreySoft;
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
