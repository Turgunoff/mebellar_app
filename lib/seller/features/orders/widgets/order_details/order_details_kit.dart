import 'package:flutter/material.dart';

import '../../../../../core/theme/app_fonts.dart';

// Local design tokens for the order-details screen. Jakarta Sans is applied
// to every `Text` explicitly so the surface is immune to seller-theme tint
// regressions.
const Color kInk = Color(0xFF1D1D1D);
const Color kGrey = Color(0xFF757575);
const Color kGreyMid = Color(0xFFBDBDBD);
const Color kGreySoft = Color(0xFFB0B0B0);
const Color kDivider = Color(0xFFEAEAEA);
const Color kOutline = Color(0xFFE3E3E3);
const Color kSurfaceMuted = Color(0xFFF5F5F5);
const Color kImageBg = Color(0xFFF0F0F0);

// Amber pill — soft tint, saturated text. Don't darken [kAmberFg] without
// re-checking contrast against [kAmberBg].
const Color kAmberBg = Color(0xFFFFF1D6);
const Color kAmberFg = Color(0xFF8C5A12);

// Soft terracotta tint for active step rings & accent backgrounds.
const Color kTerracottaSoft = Color(0xFFFBEDE6);

/// White, rounded, soft-shadowed card wrapping an order-details section.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Bold heading inside a [SectionCard].
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.seller,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: kInk,
        letterSpacing: -0.2,
        height: 1.2,
      ),
    );
  }
}

/// One physical line item within an order, as displayed in `ItemsCard`.
/// The seller order-detail screen maps the domain `OrderItem` onto this
/// presentation struct.
@immutable
class OrderItem {
  const OrderItem({
    required this.name,
    required this.qty,
    required this.unitPriceLabel,
    required this.subtotalLabel,
  });

  final String name;
  final int qty;
  final String unitPriceLabel;
  final String subtotalLabel;
}
