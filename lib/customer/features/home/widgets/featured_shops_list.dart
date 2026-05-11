import 'package:cached_network_image/cached_network_image.dart';
import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../../../shared/models/shop.dart';

class FeaturedShopsList extends StatelessWidget {
  const FeaturedShopsList({super.key, required this.shops, this.onTap});

  final List<Shop> shops;
  final ValueChanged<Shop>? onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 116,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: shops.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final shop = shops[i];
          return GestureDetector(
            onTap: onTap == null ? null : () => onTap!(shop),
            child: SizedBox(
              width: 92,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: (shop.logoUrl != null &&
                            shop.logoUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(shop.logoUrl!)
                        : null,
                    child: (shop.logoUrl == null || shop.logoUrl!.isEmpty)
                        ? Icon(
                            Icons.storefront_outlined,
                            color: scheme.outline,
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    shop.name.get(lang),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
