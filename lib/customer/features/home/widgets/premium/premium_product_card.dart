import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import 'premium_tokens.dart';

class PremiumProductCard extends StatelessWidget {
  const PremiumProductCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.shop,
    required this.price,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
  });

  final String imageUrl;
  final String name;
  final String shop;
  final String price;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 65,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: pt.imageBg),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Shimmer.fromColors(
                            baseColor: pt.imageBg,
                            highlightColor: const Color(0xFFFAFAFA),
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (_, _, _) => Icon(
                            Iconsax.gallery,
                            color: pt.greyLight,
                            size: 40,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _FrostedHeartButton(
                          isFavorite: isFavorite,
                          onTap: onFavoriteToggle,
                        ),
                      ),
                    ],
                  ),
                ),
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
                              style: PremiumTokens.body(
                                size: 12,
                                color: pt.grey,
                              ),
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
            ),
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
              // Material's favorite/favorite_border have a clear filled vs.
              // outlined contrast — Iconsax's `heart_copy` is actually a
              // duplicate of the outline, which made the active state look
              // unchanged.
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
