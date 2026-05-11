import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_colors.dart';

// Local tokens — kept here so this screen reads top-to-bottom without
// chasing theme indirection. Plus Jakarta Sans is applied to every
// `Text` explicitly per the design spec rather than inheriting from
// the seller theme; this protects the screen from theme regressions.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _greySoft = Color(0xFFB0B0B0);
const _divider = Color(0xFFEAEAEA);
const _outline = Color(0xFFE3E3E3);
const _surfaceMuted = Color(0xFFF5F5F5);
const _imageBg = Color(0xFFF0F0F0);

// Amber pill — soft tint, saturated text. Don't darken `_amberFg`
// without re-checking contrast against `_amberBg`.
const _amberBg = Color(0xFFFFF1D6);
const _amberFg = Color(0xFF8C5A12);

// Soft terracotta tint for active step rings & accent backgrounds.
const _terracottaSoft = Color(0xFFFBEDE6);

// =============================================================================
// Screen — premium order details with sticky bottom action bar.
// =============================================================================
class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const order = _kMockOrder;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: _OrderAppBar(orderId: order.orderId),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: const [
            _OrderMetaCard(
              orderId: 'ORD-2026-1102',
              date: '03 May 2026, 14:30',
              statusLabel: 'Kutilmoqda',
            ),
            SizedBox(height: 14),
            _StatusTimelineCard(currentStep: 1),
            SizedBox(height: 14),
            _CustomerCard(
              name: 'Aziz Rakhimov',
              phone: '+998 90 123 45 67',
              address:
                  "Toshkent sh., Chilonzor tumani, 9-kvartal, 12-uy, 45-xonadon",
            ),
            SizedBox(height: 14),
            _ItemsCard(items: _kMockItems),
            SizedBox(height: 14),
            _PaymentSummaryCard(
              subtotal: '12 400 000',
              delivery: '150 000',
              total: '12 550 000',
              paymentMethod: 'Naqd pul',
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: const _BottomActionBar(),
    );
  }
}

// =============================================================================
// AppBar — white surface, bold Jakarta title, hairline divider.
// =============================================================================
class _OrderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _OrderAppBar({required this.orderId});

  final String orderId;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        splashRadius: 22,
        icon: const Icon(Iconsax.arrow_left_2, size: 22, color: _ink),
      ),
      titleSpacing: 0,
      title: Text(
        'Buyurtma $orderId',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _ink,
          letterSpacing: -0.3,
          height: 1.2,
        ),
      ),
      centerTitle: false,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: _divider),
      ),
    );
  }
}

// =============================================================================
// 0. Order meta — id, placed-at, status pill. Sits above the timeline so the
// header information is glanceable without scrolling into the tracker.
// =============================================================================
class _OrderMetaCard extends StatelessWidget {
  const _OrderMetaCard({
    required this.orderId,
    required this.date,
    required this.statusLabel,
  });

  final String orderId;
  final String date;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$orderId',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Iconsax.calendar_1, size: 14, color: _grey),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _grey,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _amberBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _amberFg,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 1. Status timeline — horizontal stepper. Active = filled terracotta with
// white check; current = ring; upcoming = grey. Connector colors trail the
// last completed step so the progress reads at-a-glance.
// =============================================================================
class _StatusTimelineCard extends StatelessWidget {
  const _StatusTimelineCard({required this.currentStep});

  final int currentStep;

  static const _steps = <String>[
    'Yaratildi',
    'Qabul qilindi',
    'Tayyorlanmoqda',
    "Yo'lda",
    'Yetkazildi',
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(text: 'Buyurtma holati'),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(_steps.length, (i) {
                  final isCompleted = i < currentStep;
                  final isCurrent = i == currentStep;
                  final isLast = i == _steps.length - 1;
                  return Expanded(
                    child: _TimelineNode(
                      label: _steps[i],
                      isCompleted: isCompleted,
                      isCurrent: isCurrent,
                      showTrailingConnector: !isLast,
                      trailingConnectorActive: i < currentStep,
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    required this.showTrailingConnector,
    required this.trailingConnectorActive,
  });

  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final bool showTrailingConnector;
  final bool trailingConnectorActive;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.terracotta;
    final inactiveDot = _surfaceMuted;
    final inactiveBorder = _outline;
    final connectorActive = AppColors.terracotta;
    final connectorInactive = _divider;

    Widget dot;
    if (isCompleted) {
      dot = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: activeColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Iconsax.tick_circle, size: 16, color: Colors.white),
      );
    } else if (isCurrent) {
      dot = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: _terracottaSoft,
          shape: BoxShape.circle,
          border: Border.all(color: activeColor, width: 2),
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else {
      dot = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: inactiveDot,
          shape: BoxShape.circle,
          border: Border.all(color: inactiveBorder, width: 1),
        ),
      );
    }

    final labelColor = isCompleted || isCurrent ? _ink : _greySoft;
    final labelWeight =
        isCurrent ? FontWeight.w700 : (isCompleted ? FontWeight.w600 : FontWeight.w500);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Left half-connector — keeps the dot centered under the label.
            // Suppressed for the very first node by making it transparent.
            Expanded(
              child: Container(
                height: 2,
                color: Colors.transparent,
              ),
            ),
            dot,
            Expanded(
              child: Container(
                height: 2,
                color: showTrailingConnector
                    ? (trailingConnectorActive
                        ? connectorActive
                        : connectorInactive)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: labelWeight,
            color: labelColor,
            height: 1.25,
            letterSpacing: -0.05,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 2. Customer card — name, callable phone row, copyable address row.
// =============================================================================
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.name,
    required this.phone,
    required this.address,
  });

  final String name;
  final String phone;
  final String address;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(text: "Mijoz ma'lumotlari"),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _terracottaSoft,
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mijoz',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _grey,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: _divider),
          const SizedBox(height: 14),
          _ContactRow(
            icon: Iconsax.call,
            label: 'Telefon',
            value: phone,
            actionIcon: Iconsax.call_calling,
            actionLabel: "Qo'ng'iroq",
            onTap: () {},
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: _divider),
          const SizedBox(height: 12),
          _AddressRow(address: address),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionIcon,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Iconsax.call, size: 18, color: _grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(actionIcon, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    actionLabel,
                    style: GoogleFonts.plusJakartaSans(
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
          backgroundColor: _ink,
          content: Text(
            "Manzil nusxa olindi",
            style: GoogleFonts.plusJakartaSans(
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
          child: Icon(Iconsax.location, size: 18, color: _grey),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Yetkazib berish manzili",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: _ink,
                  height: 1.45,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: _surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => _copy(context),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.copy, size: 14, color: _ink),
                  const SizedBox(width: 6),
                  Text(
                    "Nusxa olish",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ink,
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

// =============================================================================
// 3. Items list — small image tile, name, qty x unit price, line subtotal.
// `itemCountLabel` reads "(N ta mahsulot)" where N counts physical units.
// =============================================================================
class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items});

  final List<_OrderItem> items;

  @override
  Widget build(BuildContext context) {
    final totalUnits = items.fold<int>(0, (sum, it) => sum + it.qty);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(text: 'Buyurtma tarkibi ($totalUnits ta mahsulot)'),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++) ...[
            _ItemRow(item: items[i]),
            if (i != items.length - 1) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: _divider),
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

  final _OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _imageBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Iconsax.box_1, size: 22, color: _greyMid),
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  height: 1.3,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${item.qty} ta × ${item.unitPriceLabel} UZS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _grey,
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'UZS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _greyMid,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// 4. Payment summary — three-line breakdown plus method badge.
// Total uses charcoal (not terracotta) so the figure stays neutral and the
// CTA in the bottom bar remains the only saturated accent on screen.
// =============================================================================
class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({
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
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(text: "To'lov tafsilotlari"),
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    height: 1.2,
                  ),
                ),
              ),
              RichText(
                text: TextSpan(
                  text: total,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                  children: [
                    TextSpan(
                      text: '  UZS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _greyMid,
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
                  color: _surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _outline, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.wallet_3, size: 14, color: _ink),
                    const SizedBox(width: 8),
                    Text(
                      "To'lov turi: ",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _grey,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      paymentMethod,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink,
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _grey,
              height: 1.2,
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            text: value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _ink,
              letterSpacing: -0.2,
              height: 1.2,
            ),
            children: [
              TextSpan(
                text: '  UZS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _greyMid,
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

// Hairline dashed rule — drawn with CustomPaint so we don't pull in a
// dotted-border package for a single divider.
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
      ..color = _divider
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

// =============================================================================
// Bottom action bar — sticky, white surface above safe area, soft top shadow.
// Reject (outline) on the left, Accept (filled terracotta) on the right with
// a 1.4× flex so the primary action visually dominates without overpowering.
// =============================================================================
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: _divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: _outline, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      'Rad etish',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 7,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Iconsax.tick_circle,
                            size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Buyurtmani qabul qilish',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.0,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Shared bits — section card shell + section title.
// =============================================================================
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _ink,
        letterSpacing: -0.2,
        height: 1.2,
      ),
    );
  }
}

// =============================================================================
// Mock data
// =============================================================================
@immutable
class _OrderItem {
  const _OrderItem({
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

@immutable
class _MockOrderHeader {
  const _MockOrderHeader({required this.orderId});
  final String orderId;
}

const _kMockOrder = _MockOrderHeader(orderId: '#ORD-2026-1102');

const _kMockItems = <_OrderItem>[
  _OrderItem(
    name: 'Klassik kuxnya jihozlari',
    qty: 1,
    unitPriceLabel: '10 000 000',
    subtotalLabel: '10 000 000',
  ),
  _OrderItem(
    name: 'Modern Loft stoli',
    qty: 2,
    unitPriceLabel: '1 200 000',
    subtotalLabel: '2 400 000',
  ),
];
