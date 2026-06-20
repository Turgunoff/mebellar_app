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
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: c.onPrimarySoft),
              ),
              const Spacer(),
              if (indicator != null)
                _buildIndicator(indicator!, c)
              else if (delta != null)
                DashTrendChip(
                  deltaPercent: delta,
                  lowerIsBetter: deltaLowerIsBetter,
                  compact: true,
                ),
            ],
          ),
          // Flexible so the gap compresses inside the fixed-aspect grid cell
          // when the optional subtitle line is present (e.g. the products
          // card's tariff caption) instead of overflowing the card bottom.
          const Flexible(child: SizedBox(height: 12)),
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
                    // In dark mode the brand indigo is too dark to read as a
                    // headline on the near-black surface — lift it to the light
                    // periwinkle accent; light mode keeps the deep indigo.
                    color: accentValue
                        ? (c.brightness == Brightness.dark
                              ? c.onPrimarySoft
                              : c.primary)
                        : c.ink,
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

    // The surface colour is painted by the Material (not the Container) so a
    // tappable card's ink ripple renders ON the surface instead of invisibly
    // underneath it. The Container keeps only the drop shadow (Material
    // elevation can't reproduce it); the accent border rides on the
    // Material's shape, which paints in the foreground and so survives the
    // opaque fill.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: important
              ? BorderSide(color: c.primary.withValues(alpha: 0.35))
              : BorderSide.none,
        ),
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }

  Widget _buildIndicator(KpiIndicator i, SellerColors c) {
    final (Color fg, Color bg) = switch (i.kind) {
      KpiIndicatorKind.danger => (c.negative, c.negativeBg),
      KpiIndicatorKind.accent => (c.onPrimarySoft, c.primarySoft),
      KpiIndicatorKind.warning => (c.warning, c.warningBg),
      KpiIndicatorKind.success => (c.positive, c.positiveBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        i.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Semantic intent of a [KpiIndicator]. The actual fg/bg colours are resolved
/// per theme in `_buildIndicator` from [SellerColors] so the pill flips with
/// light/dark instead of baking a fixed light tint.
enum KpiIndicatorKind { danger, accent, warning, success }

/// Tiny pill shown at the top-right of a [SellerKpiCard]. Used for surfacing
/// constraints the bare metric can't communicate (e.g. "limit exceeded" on
/// the products card). Construct via the named factories so the intent (and
/// therefore the theme-resolved colour) stays on-brand.
@immutable
class KpiIndicator {
  const KpiIndicator._({required this.label, required this.kind});

  final String label;
  final KpiIndicatorKind kind;

  factory KpiIndicator.danger(String label) =>
      KpiIndicator._(label: label, kind: KpiIndicatorKind.danger);

  /// On-brand variant: indigo foreground over a soft indigo tint. Used on
  /// cards where a hard "danger" red would feel too alarming and clash with
  /// the seller mode's premium aesthetic (e.g. a polite "Limit oshdi" nudge).
  factory KpiIndicator.accent(String label) =>
      KpiIndicator._(label: label, kind: KpiIndicatorKind.accent);

  factory KpiIndicator.warning(String label) =>
      KpiIndicator._(label: label, kind: KpiIndicatorKind.warning);

  factory KpiIndicator.success(String label) =>
      KpiIndicator._(label: label, kind: KpiIndicatorKind.success);
}
