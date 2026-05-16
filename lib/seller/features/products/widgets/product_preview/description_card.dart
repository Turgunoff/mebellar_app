import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// Description card — collapses to 5 lines with a "show more" toggle so very
/// long descriptions don't dominate the scroll.
class DescriptionCard extends StatefulWidget {
  const DescriptionCard({super.key, required this.text});

  final String text;

  @override
  State<DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<DescriptionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
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
              maxLines: _expanded ? null : 5,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: kInk,
                height: 1.55,
                letterSpacing: -0.05,
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expanded ? "Yopish" : "Ko'proq o'qish",
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.terracotta,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                    size: 14,
                    color: AppColors.terracotta,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
