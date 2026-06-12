import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../shared/widgets/image_error_placeholder.dart';
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
    this.onAddToCart,
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

  /// When set, a circular brand-coloured "+" quick-add CTA appears in the price
  /// row. Null hides it (e.g. the favourites grid / similar rail).
  final VoidCallback? onAddToCart;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _PriceBlock(price: price, oldPrice: oldPrice, pt: pt),
              ),
              if (onAddToCart != null) ...[
                const SizedBox(width: 8),
                _QuickAddButton(onTap: onAddToCart),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Strikethrough original (when discounted) stacked above the bold accent
/// effective price — stacked, not inline, so two long furniture prices never
/// fight for one narrow line.
class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.price,
    required this.oldPrice,
    required this.pt,
  });

  final String price;
  final String? oldPrice;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (oldPrice != null)
          Text(
            oldPrice!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                PremiumTokens.body(
                  size: 11.5,
                  weight: FontWeight.w500,
                  color: pt.grey,
                ).copyWith(
                  decoration: TextDecoration.lineThrough,
                  decorationColor: pt.grey,
                ),
          ),
        Text(
          price,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PremiumTokens.body(
            size: 15.5,
            weight: FontWeight.w800,
            color: PremiumTokens.accent,
            letterSpacing: -0.3,
          ),
        ),
      ],
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

/// Circular brand-terracotta quick-add CTA.
class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: PremiumTokens.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: PremiumTokens.accent.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}

/// Pill-shaped, vivid gradient discount badge over the image.
class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.percent});

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

/// Circular frosted-glass favourite toggle — a real `BackdropFilter` blur so it
/// reads as premium glassmorphism over any image.
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
