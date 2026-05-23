import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../features/home/widgets/premium/premium_tokens.dart';

/// Square 40×40 button with an "active filters" badge in the corner.
/// Used in both the search and category-product list app bars to launch
/// the filter sheet. [count] hides the badge when zero.
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final active = count > 0;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active
                  ? PremiumTokens.accent
                  : PremiumTokens.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Iconsax.setting_4,
                  color: active ? Colors.white : PremiumTokens.accent,
                  size: 17,
                ),
                if (active)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: pt.dark,
                        shape: BoxShape.circle,
                        border: Border.all(color: pt.background, width: 1.6),
                      ),
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: PremiumTokens.body(
                          size: 9,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
