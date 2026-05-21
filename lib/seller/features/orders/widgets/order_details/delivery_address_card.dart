import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

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
    final hasContact = recipientName.isNotEmpty || phone.isNotEmpty;
    final hasAddress = address.isNotEmpty;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: 'Yetkazish manzili'),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Iconsax.location,
                  size: 18,
                  color: Color(0xFF3B5BDB),
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
                        style: const TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kInk,
                          height: 1.4,
                        ),
                      )
                    else
                      const Text(
                        'Manzil ko\'rsatilmagan',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 13,
                          color: kGrey,
                        ),
                      ),
                    if (hasContact) ...[
                      const SizedBox(height: 6),
                      if (recipientName.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Iconsax.user, size: 13, color: kGrey),
                            const SizedBox(width: 5),
                            Text(
                              recipientName,
                              style: const TextStyle(
                                fontFamily: AppFonts.seller,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: kGrey,
                              ),
                            ),
                          ],
                        ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Iconsax.call, size: 13, color: kGrey),
                            const SizedBox(width: 5),
                            Text(
                              phone,
                              style: const TextStyle(
                                fontFamily: AppFonts.seller,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: kGrey,
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
