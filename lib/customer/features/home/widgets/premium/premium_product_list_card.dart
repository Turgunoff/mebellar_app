import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../shared/widgets/image_error_placeholder.dart';
import 'premium_card_parts.dart';
import 'premium_tokens.dart';

/// Full-width list variant of the premium product card — a strict square
/// thumbnail on the left, details (name, subtitle, price) on the right. Used by
/// the home feed and the per-category product list when the user picks the
/// "list" view mode. Like [PremiumProductCard] it has **no** quick-add: tapping
/// the card opens the detail screen where the cart/colour picker lives.
class PremiumProductListCard extends StatelessWidget {
  const PremiumProductListCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.price,
    this.subtitle = '',
    this.oldPrice,
    this.discountPercent = 0,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
    this.heroTag,
  });

  final String imageUrl;
  final String name;

  /// Effective (already-discounted) price string.
  final String price;

  /// Thin grey secondary line (description / shop name). Hidden when empty.
  final String subtitle;

  /// Original list price, struck through above [price]. Null hides it.
  final String? oldPrice;

  /// Whole-percent discount for the corner pill; 0 hides it.
  final int discountPercent;

  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  /// Shared-element tag for the row → product-detail image transition. Pass
  /// `'product-${id}-0'` to match the detail gallery's first-image [Hero]; null
  /// disables it. See [PremiumProductCard.heroTag].
  final String? heroTag;

  /// Strict square thumbnail. A fixed box (not a content-driven strip) is what
  /// keeps every list row's image at the same 1:1 proportion — so a 1-line and a
  /// 2-line product read as one uniform column instead of a mix of tall and
  /// square images.
  static const double _imageSize = 120;
  // Floor for the content column so a short (1-line, no-discount) row still rests
  // at the thumbnail's height rather than collapsing shorter than the square. The
  // card grows past this when the name wraps or the OS font scale is large, so it
  // never overflows — the thumbnail then centres against the taller content.
  static const double _minContentHeight = _imageSize - 24;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);

    // Only the photo rides the Hero — the discount badge stays with the row.
    Widget photo = CachedNetworkImage(
      imageUrl: imageUrl,
      // cover crops to fill the square box instead of letter-boxing or
      // distorting, so portrait and landscape source images both sit flush.
      fit: BoxFit.cover,
      memCacheWidth: 400,
      placeholder: (_, _) => Shimmer.fromColors(
        baseColor: pt.imageBg,
        // Token, not a hardcoded near-white — keeps the sweep subtle on the
        // dark imageBg in dark mode.
        highlightColor: pt.surface,
        child: Container(color: pt.surface),
      ),
      errorWidget: (_, _, _) => const ImageErrorPlaceholder(iconSize: 28),
    );
    if (heroTag != null) photo = Hero(tag: heroTag!, child: photo);

    final image = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: pt.imageBg),
        photo,
        if (discountPercent > 0)
          Positioned(
            top: 10,
            left: 10,
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
          child: Stack(
            children: [
              Row(
                // Centre the fixed square against the content: short rows rest at
                // the 120px thumbnail height (image fills the left flush); when a
                // long name or a large font scale makes the content taller, the
                // card grows and the square sits centred rather than stretching.
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: _imageSize, height: _imageSize, child: image),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: _minContentHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
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
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PremiumTokens.body(
                                  size: 12,
                                  color: pt.grey,
                                ),
                              ),
                            ],
                            // Price sits on the left of the content column, so it
                            // gets the full text width and scales down rather than
                            // truncating.
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: PremiumPriceBlock(
                                price: price,
                                oldPrice: oldPrice,
                                pt: pt,
                                priceSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 10,
                right: 10,
                child: PremiumFrostedHeartButton(
                  isFavorite: isFavorite,
                  onTap: onFavoriteToggle,
                  size: 34,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
