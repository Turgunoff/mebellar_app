import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../core/theme/premium_tokens.dart';

/// Shared building blocks for the premium product cards (grid + list variants).
/// Centralised so the discount pill, frosted heart, and price block render and
/// behave identically across both layouts — change the look in one place.

/// Strikethrough original (when discounted) stacked above the bold accent
/// effective price. Each line is wrapped in a left-aligned [FittedBox] so a long
/// furniture price (e.g. `6,292,203 UZS`) scales down to fit the freed-up width
/// instead of truncating with an ellipsis — the quick-add button used to eat
/// this space.
class PremiumPriceBlock extends StatelessWidget {
  const PremiumPriceBlock({
    super.key,
    required this.price,
    required this.oldPrice,
    required this.pt,
    this.priceSize = 15.5,
  });

  final String price;
  final String? oldPrice;
  final PremiumTokens pt;

  /// Effective-price font size. The list card runs slightly larger than the
  /// denser masonry card.
  final double priceSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (oldPrice != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              oldPrice!,
              maxLines: 1,
              softWrap: false,
              style:
                  PremiumTokens.body(
                    size: priceSize - 4,
                    weight: FontWeight.w500,
                    color: pt.grey,
                  ).copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: pt.grey,
                  ),
            ),
          ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            price,
            maxLines: 1,
            softWrap: false,
            style: PremiumTokens.body(
              size: priceSize,
              weight: FontWeight.w800,
              color: PremiumTokens.accent,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill-shaped, vivid gradient discount badge over the image.
class PremiumDiscountBadge extends StatelessWidget {
  const PremiumDiscountBadge({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9573F), Color(0xFFC0392B)],
        ),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC0392B).withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '-$percent%',
        style: PremiumTokens.body(
          size: 11,
          weight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Circular frosted-glass favourite toggle — a real [BackdropFilter] blur so it
/// reads as premium glassmorphism over any image.
class PremiumFrostedHeartButton extends StatelessWidget {
  const PremiumFrostedHeartButton({
    super.key,
    required this.isFavorite,
    this.onTap,
    this.size = 36,
  });

  final bool isFavorite;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A2A).withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.42),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3A3A3A)
                      : Colors.white.withValues(alpha: 0.65),
                  width: 1,
                ),
              ),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? PremiumTokens.accent : pt.dark,
                size: size * 0.56,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
