import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../data/dashboard_models.dart';
import 'dashboard_kit.dart';

/// "Eng ko'p sotilgan" — a compact ranked list of the month's best sellers.
/// Each row shows a thumbnail, the product name, a "units · revenue" line, and
/// a period-over-period trend chip (analytics-style) instead of a fill bar —
/// the seller cares more about *which way* a product is moving than its share.
class TopProductsCard extends StatelessWidget {
  const TopProductsCard({super.key, required this.products});

  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < products.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.divider),
            _ProductRow(product: products[i]),
          ],
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});

  final TopProduct product;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: product.imageUrl == null
                ? _ThumbPlaceholder(color: c.imageBg, icon: c.greyMid)
                : CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    width: 48,
                    height: 48,
                    memCacheWidth: 150,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        _ThumbPlaceholder(color: c.imageBg, icon: c.greyMid),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      tr(
                        'dashboard.units_pieces',
                        namedArgs: {'count': product.unitsSold.toString()},
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DashKit.indigo,
                        height: 1.1,
                      ),
                    ),
                    const _Dot(),
                    Flexible(
                      child: Text(
                        tr(
                          'common.currency_som_2',
                          namedArgs: {
                            'amount': DashKit.compactMoney(product.revenue),
                          },
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.grey,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DashTrendChip(deltaPercent: product.deltaPercent, compact: true),
        ],
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder({required this.color, required this.icon});

  final Color color;
  final Color icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: color,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: 20, color: icon),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: c.greyMid,
          height: 1.0,
        ),
      ),
    );
  }
}
