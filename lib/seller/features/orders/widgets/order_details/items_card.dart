import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'order_details_kit.dart';

/// Order line-items list. The title's count reads "(N ta mahsulot)" where N
/// is the total number of physical units across all rows.
class ItemsCard extends StatelessWidget {
  const ItemsCard({super.key, required this.items});

  final List<OrderItem> items;

  @override
  Widget build(BuildContext context) {
    final totalUnits = items.fold<int>(0, (sum, it) => sum + it.qty);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(text: 'Buyurtma tarkibi ($totalUnits ta mahsulot)'),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++) ...[
            _ItemRow(item: items[i]),
            if (i != items.length - 1) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: kDivider),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: kImageBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Iconsax.box_1, size: 22, color: kGreyMid),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                  height: 1.3,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${item.qty} ta × ${item.unitPriceLabel} UZS',
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kGrey,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.subtotalLabel,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kInk,
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'UZS',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: kGreyMid,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
