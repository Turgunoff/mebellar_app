import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'dashboard_kit.dart';

/// Premium KPI tile used on the seller dashboard 2×2 grid.
///
/// Visual contract: pure white surface, 16px radius, a clean drop shadow,
/// and an optional Indigo border on the headline metric so the eye lands
/// there first. The card is intentionally never dimmed — pre-approval state
/// is communicated by the amber banner, not by lowering data contrast.
///
/// Accent color is `AppColors.sellerPrimary` (Deep Indigo) — distinct from
/// the customer surface's accent so the seller dashboard reads as
/// "Backoffice" on first glance.
///
/// Long values (e.g. "151 850 000 UZS") are wrapped in a `FittedBox` so they
/// shrink to fit instead of getting truncated with an ellipsis.
///
/// Typography note: every `TextStyle` here intentionally omits `fontFamily`.
/// The seller theme pins the family to Plus Jakarta Sans via
/// `AppTypography.plusJakartaSansTextTheme(...)`, and the styles below merge
/// on top of that default. Don't reintroduce a hardcoded `AppFonts.xxx(...)`
/// here — it would defeat the theme-level swap.
class SellerKpiCard extends StatelessWidget {
  const SellerKpiCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.unit,
    this.subtitle,
    this.indicator,
    this.delta,
    this.deltaLowerIsBetter = false,
    this.accentValue = false,
    this.important = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;

  /// Trailing unit (e.g. "UZS") rendered next to the value in muted grey.
  final String? unit;

  /// Optional second-line caption (e.g. tariff plan name).
  final String? subtitle;

  /// Optional small indicator pill in the top-right (e.g. "Limit oshdi").
  final KpiIndicator? indicator;

  /// Optional period-over-period delta (e.g. `12.0` ⇒ "+12.0%"). Rendered as
  /// a trend chip in the top-right when no [indicator] is set. `null` ⇒ no
  /// chip (a metric with no comparison yet).
  final double? delta;

  /// Flips the delta colour rule — used for metrics like pending orders where
  /// a downward trend is the good outcome.
  final bool deltaLowerIsBetter;

  /// Renders [value] in the brand indigo — used for the headline metric.
  final bool accentValue;

  /// Adds a subtle indigo border so the card stands out in the grid.
  final bool important;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: important
            ? Border.all(color: AppColors.sellerPrimary.withValues(alpha: 0.35))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.sellerPrimaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.sellerPrimaryDeep),
              ),
              const Spacer(),
              if (indicator != null)
                _buildIndicator(indicator!)
              else if (delta != null)
                DashTrendChip(
                  deltaPercent: delta,
                  lowerIsBetter: deltaLowerIsBetter,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.grey,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          // FittedBox prevents long values like "151 850 000 UZS" from being
          // truncated to "151 850 0..." in the narrow KPI cell. It only
          // scales down when the natural size doesn't fit, so short values
          // (e.g. "17") render at full 22px without distortion.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.1,
                    color: accentValue ? AppColors.sellerPrimary : c.ink,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.greyFaint,
                      height: 1.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: c.greyFaint,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }

  Widget _buildIndicator(KpiIndicator i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: i.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        i.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: i.fg,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Tiny pill shown at the top-right of a [SellerKpiCard]. Used for surfacing
/// constraints the bare metric can't communicate (e.g. "limit exceeded" on
/// the products card). Construct via the named factories so colors stay
/// on-brand.
@immutable
class KpiIndicator {
  const KpiIndicator._({
    required this.label,
    required this.fg,
    required this.tint,
  });

  final String label;
  final Color fg;
  final Color tint;

  factory KpiIndicator.danger(String label) => KpiIndicator._(
    label: label,
    fg: AppColors.sellerNegative,
    tint: AppColors.sellerNegativeBg,
  );

  /// On-brand variant: Deep Indigo foreground over a soft Indigo tint.
  /// Used on cards where a hard "danger" red would feel too alarming and
  /// clash with the seller mode's premium aesthetic (e.g. a polite
  /// "Limit oshdi" nudge on the products tile).
  factory KpiIndicator.accent(String label) => KpiIndicator._(
    label: label,
    fg: AppColors.sellerPrimaryDeep,
    tint: AppColors.sellerPrimaryTint,
  );

  factory KpiIndicator.warning(String label) => KpiIndicator._(
    label: label,
    fg: AppColors.sellerWarning,
    tint: AppColors.sellerWarningBg,
  );

  factory KpiIndicator.success(String label) => KpiIndicator._(
    label: label,
    fg: AppColors.sellerPositive,
    tint: AppColors.sellerPositiveBg,
  );
}
