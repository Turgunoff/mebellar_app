import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'order_details_kit.dart';

/// Three-line payment breakdown plus a method badge. The total uses charcoal
/// (not terracotta) so the only saturated accent on screen stays the CTA.
class PaymentSummaryCard extends StatelessWidget {
  const PaymentSummaryCard({
    super.key,
    required this.subtotal,
    required this.delivery,
    required this.total,
    required this.paymentMethod,
  });

  final String subtotal;
  final String delivery;
  final String total;
  final String paymentMethod;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: "To'lov tafsilotlari"),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Mahsulotlar summasi', value: subtotal),
          const SizedBox(height: 10),
          _SummaryLine(label: 'Yetkazib berish', value: delivery),
          const SizedBox(height: 14),
          const _DashedDivider(),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Jami',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                    height: 1.2,
                  ),
                ),
              ),
              RichText(
                text: TextSpan(
                  text: total,
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                  children: const [
                    TextSpan(
                      text: '  UZS',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kGreyMid,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: kSurfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: kOutline, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.wallet_3, size: 14, color: kInk),
                    const SizedBox(width: 8),
                    const Text(
                      "To'lov turi: ",
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: kGrey,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      paymentMethod,
                      style: const TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                        height: 1.0,
                      ),
                    ),
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

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kGrey,
              height: 1.2,
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            text: value,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kInk,
              letterSpacing: -0.2,
              height: 1.2,
            ),
            children: const [
              TextSpan(
                text: '  UZS',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kGreyMid,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hairline dashed rule — drawn with CustomPaint so we don't pull in a
/// dotted-border package for a single divider.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (_, c) => CustomPaint(
          size: Size(c.maxWidth, 1),
          painter: _DashedLinePainter(),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    final paint = Paint()
      ..color = kDivider
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
