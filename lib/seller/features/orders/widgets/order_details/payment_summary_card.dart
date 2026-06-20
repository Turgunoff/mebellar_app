import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import 'order_details_kit.dart';

/// Three-line payment breakdown plus a method badge. The total uses charcoal
/// (not the brand indigo) so the only saturated accent on screen stays the CTA.
///
/// When [proposedDelivery] is non-null the card shows a pending-fee banner.
/// [onSetFee] wires the "Narxni o'zgartirish" button — omit to hide it.
class PaymentSummaryCard extends StatelessWidget {
  const PaymentSummaryCard({
    super.key,
    required this.subtotal,
    required this.delivery,
    required this.total,
    required this.paymentMethod,
    this.proposedDelivery,
    this.feeAdjustmentNote,
    this.onSetFee,
  });

  final String subtotal;
  final String delivery;
  final String total;
  final String paymentMethod;
  final String? proposedDelivery;
  final String? feeAdjustmentNote;
  final VoidCallback? onSetFee;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
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
              Expanded(
                child: Text(
                  'Jami',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    height: 1.2,
                  ),
                ),
              ),
              RichText(
                text: TextSpan(
                  text: total,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                  children: [
                    TextSpan(
                      text: '  UZS',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.greyMid,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (proposedDelivery != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: c.warning.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Iconsax.warning_2,
                        size: 16,
                        color: c.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Yangi yetkazish narxi taklif qilindi',
                          style: TextStyle(
                            fontFamily: AppFonts.seller,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.warning,
                          ),
                        ),
                      ),
                      Text(
                        '$proposedDelivery UZS',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: c.warning,
                        ),
                      ),
                    ],
                  ),
                  if (feeAdjustmentNote?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      feeAdjustmentNote!,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        color: c.warning,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Mijoz tasdiqlashini kutmoqda…',
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: c.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onSetFee != null && proposedDelivery == null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSetFee,
                icon: const Icon(Iconsax.edit, size: 15),
                label: const Text(
                  'Yetkazish narxini o\'zgartirish',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sellerPrimary,
                  side: const BorderSide(color: AppColors.sellerPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: c.fillSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.outline, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.wallet_3, size: 14, color: c.ink),
                    const SizedBox(width: 8),
                    Text(
                      "To'lov turi: ",
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.grey,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      paymentMethod,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
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
    final c = SellerColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.grey,
              height: 1.2,
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            text: value,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.ink,
              letterSpacing: -0.2,
              height: 1.2,
            ),
            children: [
              TextSpan(
                text: '  UZS',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.greyMid,
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
    final dividerColor = SellerColors.of(context).dividerStrong;
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (_, c) => CustomPaint(
          size: Size(c.maxWidth, 1),
          painter: _DashedLinePainter(dividerColor),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
