import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../shared/widgets/image_error_placeholder.dart';
import 'premium_card_parts.dart';
import 'premium_tokens.dart';

/// Premium, conversion-optimised product card used across the customer browse
/// surfaces (home masonry feed, search / shop / catalog grids, similar-products
/// rail). Two layout modes share one content block:
///
/// - **Masonry** (`customImageHeight` set): the image is a fixed-height box and
///   the card sizes to its intrinsic height — for `SliverMasonryGrid`.
/// - **Fixed** (`customImageHeight` null): the image `Expanded`s to fill a
///   bounded aspect-ratio cell; the content sizes to its natural height.
class PremiumProductCard extends StatelessWidget {
  const PremiumProductCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.price,
    this.subtitle = '',
    this.oldPrice,
    this.discountPercent = 0,
    this.rating,
    this.reviewCount,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
    this.customImageHeight,
  });

  final String imageUrl;
  final String name;

  /// Effective (already-discounted) price string, shown prominently in the
  /// brand accent colour.
  final String price;

  /// Thin grey secondary line (description / shop name). Hidden when empty.
  final String subtitle;

  /// Original list price, rendered struck-through above [price]. Pass it only
  /// for a discounted product; null hides the strikethrough.
  final String? oldPrice;

  /// Whole-percent discount for the corner pill; 0 hides it.
  final int discountPercent;

  /// Optional social proof. The rating row only renders when [rating] is
  /// non-null — the product-feed payload carries no per-product rating yet, so
  /// today it stays hidden until the backend supplies it.
  final double? rating;
  final int? reviewCount;

  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  /// Fixed image height that switches the card into masonry mode.
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
            // Token, not a hardcoded near-white — otherwise the shimmer sweeps
            // a bright band across the dark card in dark mode.
            highlightColor: pt.surface,
            child: Container(color: Colors.white),
          ),
          errorWidget: (_, _, _) => const ImageErrorPlaceholder(iconSize: 32),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: PremiumFrostedHeartButton(
            isFavorite: isFavorite,
            onTap: onFavoriteToggle,
          ),
        ),
        if (discountPercent > 0)
          Positioned(
            top: 12,
            left: 12,
            child: PremiumDiscountBadge(percent: discountPercent),
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
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: customImageHeight, child: imageStack),
                    _content(pt),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: imageStack),
                    _content(pt),
                  ],
                ),
        ),
      ),
    );
  }

  /// The text/price block under the image — identical in both layout modes.
  Widget _content(PremiumTokens pt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PremiumTokens.body(
              size: 15,
              weight: FontWeight.w700,
              color: pt.dark,
              height: 1.25,
              letterSpacing: -0.2,
            ),
          ),
          if (rating != null) ...[
            const SizedBox(height: 5),
            _RatingRow(rating: rating!, reviewCount: reviewCount, pt: pt),
          ],
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PremiumTokens.body(size: 12, color: pt.grey),
            ),
          ],
          const SizedBox(height: 9),
          // Full-width now that the quick-add "+" is gone — the price block
          // expands to show the whole number (scaling down before truncating).
          PremiumPriceBlock(price: price, oldPrice: oldPrice, pt: pt),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.rating,
    required this.reviewCount,
    required this.pt,
  });

  final double rating;
  final int? reviewCount;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final label = reviewCount != null
        ? '${rating.toStringAsFixed(1)} ($reviewCount)'
        : rating.toStringAsFixed(1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFE8A33D)),
        const SizedBox(width: 3),
        Text(
          label,
          style: PremiumTokens.body(
            size: 11.5,
            weight: FontWeight.w600,
            color: pt.grey,
          ),
        ),
      ],
    );
  }
}
