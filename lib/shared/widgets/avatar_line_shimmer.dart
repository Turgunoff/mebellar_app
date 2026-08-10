import 'package:flutter/material.dart';

import '../../core/theme/premium_tokens.dart';
import 'shimmer_placeholder.dart';

/// Shared "avatar + two text lines" skeleton card — the shape every
/// profile-style loading placeholder (seller banner slot, user identity
/// card, …) boils down to. Built on [ShimmerBox] for the avatar circle and
/// the two text-line bars; every visible dimension is a parameter so each
/// call site keeps its own exact look.
class AvatarLineShimmer extends StatelessWidget {
  const AvatarLineShimmer({
    super.key,
    required this.avatarSize,
    required this.cardBorderRadius,
    required this.padding,
    this.showShadow = true,
    this.line1Height = 16,
    this.line1Width = 150,
    this.line2Height = 12,
    this.line2Width,
  });

  final double avatarSize;
  final double cardBorderRadius;
  final EdgeInsetsGeometry padding;
  final bool showShadow;
  final double line1Height;
  final double line1Width;
  final double line2Height;

  /// Null keeps the second line full-width (matches the seller-banner
  /// shimmer); pass a fixed width for a shorter second line (matches the
  /// user-card shimmer).
  final double? line2Width;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: showShadow ? PremiumTokens.softShadow : null,
      ),
      child: Row(
        children: [
          ShimmerBox(
            width: avatarSize,
            height: avatarSize,
            borderRadius: avatarSize / 2,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  height: line1Height,
                  width: line1Width,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                ShimmerBox(
                  height: line2Height,
                  width: line2Width ?? double.infinity,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
