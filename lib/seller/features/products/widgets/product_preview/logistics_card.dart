import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// Buyer-facing logistics summary: production lead time, delivery cost,
/// installation availability and warranty period. Replaces the developer-
/// facing identifiers card that used to live in this slot.
///
/// Each row uses a *primary* + *secondary* value split — primary (price /
/// duration) sits on the leading line of the trailing column, secondary
/// (e.g. "Toshkent ichida") wraps onto a second line so a longer caption
/// never squeezes the leading label.
class LogisticsCard extends StatelessWidget {
  const LogisticsCard({
    super.key,
    required this.productionTimeDays,
    required this.hasDelivery,
    required this.deliveryPrice,
    required this.hasInstallation,
    required this.installationPrice,
    required this.warrantyMonths,
  });

  final String? productionTimeDays;
  final bool hasDelivery;
  final num deliveryPrice;
  final bool hasInstallation;
  final num installationPrice;
  final int warrantyMonths;

  String _priceLabel(num value) {
    if (value <= 0) return 'Bepul';
    final format = NumberFormat('#,###', 'uz');
    return '${format.format(value)} UZS';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <_LogisticsRow>[
      if (productionTimeDays != null && productionTimeDays!.trim().isNotEmpty)
        _LogisticsRow(
          icon: Iconsax.clock,
          label: 'Tayyorlash muddati',
          primary: '${productionTimeDays!.trim()} kun',
        ),
      _LogisticsRow(
        icon: Iconsax.truck_fast,
        label: 'Yetkazib berish',
        primary: hasDelivery ? _priceLabel(deliveryPrice) : 'Yo\'q',
        secondary: hasDelivery ? 'Toshkent ichida' : null,
        muted: !hasDelivery,
      ),
      _LogisticsRow(
        icon: Iconsax.setting_4,
        label: "O'rnatib berish",
        primary: hasInstallation ? _priceLabel(installationPrice) : 'Yo\'q',
        muted: !hasInstallation,
      ),
      if (warrantyMonths > 0)
        _LogisticsRow(
          icon: Iconsax.shield_tick,
          label: 'Kafolat',
          primary: '$warrantyMonths oy',
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: 'Yetkazish va kafolat'),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _RowTile(row: rows[i]),
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, thickness: 1, color: kDivider),
          ],
        ],
      ),
    );
  }
}

class _LogisticsRow {
  const _LogisticsRow({
    required this.icon,
    required this.label,
    required this.primary,
    this.secondary,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String primary;
  final String? secondary;
  final bool muted;
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final _LogisticsRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: kSurfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(row.icon, size: 16, color: kGrey),
        ),
        const SizedBox(width: 12),
        // Label stays its natural width up to ~45% of the row so a long
        // value never wraps the label. Value column is bounded too so very
        // long copy splits across two lines instead of overflowing.
        Expanded(
          flex: 5,
          child: Text(
            row.label,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kGrey,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                row.primary,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: row.muted ? kGreyMid : kInk,
                  height: 1.25,
                  letterSpacing: -0.05,
                ),
              ),
              if (row.secondary != null) ...[
                const SizedBox(height: 2),
                Text(
                  row.secondary!,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: kGrey,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
