import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../shared/widgets/image_error_placeholder.dart';
import 'premium_tokens.dart';

class PremiumProductCard extends StatelessWidget {
  const PremiumProductCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.shop,
    required this.price,
    this.discountPercent = 0,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
    this.customImageHeight,
  });

  final String imageUrl;
  final String name;
  final String shop;

  /// Effective (already discounted) price string shown prominently. The
  /// struck-through original is intentionally not shown on the narrow card —
  /// the corner `-X%` badge conveys the discount; the detail page shows both.
  final String price;

  /// Whole-percent discount for the corner badge; 0 hides the badge.
  final int discountPercent;

  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  /// When set, the image area is a fixed-height [SizedBox] and the card
  /// sizes to its intrinsic height — required for masonry / staggered grids.
  /// When null the card uses the original [Expanded]-based layout and expects
  /// a fixed-height parent (e.g. a standard aspect-ratio grid cell).
  final double? customImageHeight;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);

    final imageStack = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: pt.imageBg),
        CachedNetworkImage(
          imageUrl: imageUrl,
          width: double.infinity,
          // ROADMAP B.7 — bound the in-memory decode for the home feed cards.
          memCacheWidth: 600,
          fit: BoxFit.cover,
          placeholder: (_, _) => Shimmer.fromColors(
            baseColor: pt.imageBg,
            highlightColor: const Color(0xFFFAFAFA),
            child: Container(color: Colors.white),
          ),
          errorWidget: (_, _, _) => const ImageErrorPlaceholder(iconSize: 32),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _FrostedHeartButton(
            isFavorite: isFavorite,
            onTap: onFavoriteToggle,
          ),
        ),
        if (discountPercent > 0)
          Positioned(
            top: 12,
            left: 12,
            child: _DiscountBadge(percent: discountPercent),
          ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: PremiumTokens.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: customImageHeight != null
              ? _buildMasonryLayout(pt, imageStack)
              : _buildFixedLayout(pt, imageStack),
        ),
      ),
    );
  }

  /// Variable-height layout for masonry grids. The Column has no [Expanded]
  /// children so it sizes to its natural content height.
  Widget _buildMasonryLayout(PremiumTokens pt, Widget imageStack) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: customImageHeight, child: imageStack),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PremiumTokens.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: pt.dark,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                shop,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PremiumTokens.body(size: 12, color: pt.grey),
              ),
              const SizedBox(height: 8),
              Text(
                price,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PremiumTokens.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: PremiumTokens.accent,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Fixed-height layout for standard aspect-ratio grid cells (Favorites,
  /// Catalog, etc.). Uses [Expanded] to fill the parent's bounded height.
  Widget _buildFixedLayout(PremiumTokens pt, Widget imageStack) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 65, child: imageStack),
        Expanded(
          flex: 35,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PremiumTokens.body(
                        size: 15,
                        weight: FontWeight.w700,
                        color: pt.dark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shop,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PremiumTokens.body(size: 12, color: pt.grey),
                    ),
                  ],
                ),
                Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumTokens.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: PremiumTokens.accent,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Solid corner badge showing the discount percentage over the image.
class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFC0392B),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
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

class _FrostedHeartButton extends StatelessWidget {
  const _FrostedHeartButton({required this.isFavorite, this.onTap});

  final bool isFavorite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
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
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
