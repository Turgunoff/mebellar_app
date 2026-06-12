import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../shared/widgets/image_error_placeholder.dart';
import 'premium_card_parts.dart';
import 'premium_tokens.dart';

/// Full-width list variant of the premium product card — image on the left,
/// details (name, subtitle, price) on the right. Used by the home feed's "list"
/// view mode. Like [PremiumProductCard] it has **no** quick-add: tapping the
/// card opens the detail screen where the cart/colour picker lives.
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

  static const double _height = 132;
  static const double _imageWidth = 124;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);

    final image = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: pt.imageBg),
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          memCacheWidth: 400,
          placeholder: (_, _) => Shimmer.fromColors(
            baseColor: pt.imageBg,
            highlightColor: const Color(0xFFFAFAFA),
            child: Container(color: Colors.white),
          ),
          errorWidget: (_, _, _) => const ImageErrorPlaceholder(iconSize: 28),
        ),
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
        height: _height,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: _imageWidth, child: image),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          const Spacer(),
                          // `_imageWidth` is reserved by the heart's hit area on
                          // the right, but the price is on the left of the
                          // content column, so it gets the full text width and
                          // scales down rather than truncating.
                          PremiumPriceBlock(
                            price: price,
                            oldPrice: oldPrice,
                            pt: pt,
                            priceSize: 17,
                          ),
                        ],
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
