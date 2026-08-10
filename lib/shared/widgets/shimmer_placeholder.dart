import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_theme_extension.dart';

/// Shared shimmer-style loading placeholder — built on `package:shimmer`, the
/// same engine every per-screen skeleton already reaches for, with
/// cross-mode-safe colors (`AppCustomColors` is registered on both the
/// customer and seller theme) so it can be dropped into either mode without
/// importing the customer-only `PremiumTokens`.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final base = context.customColors.imageBackground;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
