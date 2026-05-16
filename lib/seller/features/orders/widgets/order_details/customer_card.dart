import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'order_details_kit.dart';

/// Customer block — name, callable phone row, copyable delivery address.
class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.name,
    required this.phone,
    required this.address,
  });

  final String name;
  final String phone;
  final String address;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: "Mijoz ma'lumotlari"),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kTerracottaSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Iconsax.user,
                  size: 20,
                  color: AppColors.terracotta,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mijoz',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: kGrey,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: kDivider),
          const SizedBox(height: 14),
          _ContactRow(
            label: 'Telefon',
            value: phone,
            actionIcon: Iconsax.call_calling,
            actionLabel: "Qo'ng'iroq",
            onTap: () {},
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: kDivider),
          const SizedBox(height: 12),
          _AddressRow(address: address),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.label,
    required this.value,
    required this.actionIcon,
    required this.actionLabel,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Iconsax.call, size: 18, color: kGrey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: kGrey,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                  height: 1.2,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.terracotta,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(actionIcon, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    actionLabel,
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address});

  final String address;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: kInk,
          content: const Text(
            "Manzil nusxa olindi",
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Iconsax.location, size: 18, color: kGrey),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Yetkazib berish manzili",
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: kGrey,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: kInk,
                  height: 1.45,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: kSurfaceMuted,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => _copy(context),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.copy, size: 14, color: kInk),
                  const SizedBox(width: 6),
                  Text(
                    "Nusxa olish",
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
