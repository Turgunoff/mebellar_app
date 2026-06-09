import 'package:flutter/material.dart';

import '../data/dashboard_mock.dart';
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
    return DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < products.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: DashKit.hairline),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              product.imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 48,
                height: 48,
                color: const Color(0xFFF0F0F0),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_outlined,
                  size: 20,
                  color: DashKit.greyMid,
                ),
              ),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DashKit.ink,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${product.unitsSold} dona',
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
                        "${DashKit.compactMoney(product.revenue)} so'm",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: DashKit.grey,
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

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: DashKit.greyMid,
          height: 1.0,
        ),
      ),
    );
  }
}
