import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/i18n/i18n.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'order_details_kit.dart';

class DeliveryAddressCard extends StatelessWidget {
  const DeliveryAddressCard({
    super.key,
    required this.address,
    required this.recipientName,
    required this.phone,
  });

  final String address;
  final String recipientName;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final hasContact = recipientName.isNotEmpty || phone.isNotEmpty;
    final hasAddress = address.isNotEmpty;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(text: tr('seller_orders.delivery_address_title')),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.infoBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Iconsax.location,
                  size: 18,
                  color: c.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasAddress)
                      Text(
                        address,
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                          height: 1.4,
                        ),
                      )
                    else
                      Text(
                        tr('seller_orders.address_missing'),
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 13,
                          color: c.grey,
                        ),
                      ),
                    if (hasContact) ...[
                      const SizedBox(height: 6),
                      if (recipientName.isNotEmpty)
                        Row(
                          children: [
                            Icon(Iconsax.user, size: 13, color: c.grey),
                            const SizedBox(width: 5),
                            Text(
                              recipientName,
                              style: TextStyle(
                                fontFamily: AppFonts.seller,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: c.grey,
                              ),
                            ),
                          ],
                        ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Iconsax.call, size: 13, color: c.grey),
                            const SizedBox(width: 5),
                            Text(
                              phone,
                              style: TextStyle(
                                fontFamily: AppFonts.seller,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: c.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
