import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// Description card. Collapses to [collapsedMaxLines] lines with a "Ko'proq
/// o'qish" / "Yopish" toggle — but the toggle only appears when the text
/// actually overflows that line cap. Short descriptions render in their
/// natural height with no toggle below.
class DescriptionCard extends StatefulWidget {
  const DescriptionCard({
    super.key,
    required this.text,
    this.collapsedMaxLines = 4,
  });

  final String text;
  final int collapsedMaxLines;

  @override
  State<DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<DescriptionCard> {
  bool _expanded = false;

  static const _textStyle = TextStyle(
    fontFamily: AppFonts.seller,
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: kInk,
    height: 1.55,
    letterSpacing: -0.05,
  );

  bool _overflows(BuildContext context, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: _textStyle),
      maxLines: widget.collapsedMaxLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final overflows = _overflows(context, constraints.maxWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(text: 'Tavsif'),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: Text(
                  widget.text,
                  maxLines: _expanded ? null : widget.collapsedMaxLines,
                  overflow: _expanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: _textStyle,
                ),
              ),
              if (overflows) ...[
                const SizedBox(height: 10),
                _ToggleButton(
                  expanded: _expanded,
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.terracotta.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                expanded ? 'Yopish' : "Ko'proq o'qish",
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.terracotta,
                  height: 1.2,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                expanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                size: 14,
                color: AppColors.terracotta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
