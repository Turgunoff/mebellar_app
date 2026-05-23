import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';

/// Shared design tokens for the analytics surface — kept here so every
/// tab renders with the same ink/grey palette without re-importing
/// theme constants in each file.
class AnalyticsTokens {
  AnalyticsTokens._();

  static const Color ink = Color(0xFF1D1D1D);
  static const Color grey = Color(0xFF757575);
  static const Color greyMid = Color(0xFFBDBDBD);
  static const Color placeholderBg = Color(0xFFF1F1F1);
  static const Color segmentBg = Color(0xFFEFEFEF);
  static const Color positive = AppColors.terracotta;
  static const Color negative = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF22C55E);
  static const Color info = Color(0xFF3949AB);

  /// Donut/series palette — slices cycle through this list in order.
  static const List<Color> chartPalette = <Color>[
    AppColors.terracotta,
    Color(0xFF2C3E50),
    Color(0xFFF39C12),
    Color(0xFF3949AB),
    Color(0xFF22C55E),
    Color(0xFFBDC3C7),
  ];
}

/// "Today" / "Yesterday" / "DD MMM" / "MMM yyyy" date formatter used
/// across analytics tabs for chart axis labels and review timestamps.
class AnalyticsFmt {
  AnalyticsFmt._();

  static final _wholeUzs = NumberFormat('#,##0', 'uz_UZ');
  static final _shortMonth = DateFormat('d MMM', 'uz_UZ');
  static final _monthYear = DateFormat('MMM yyyy', 'uz_UZ');
  static final _hour = DateFormat('HH:mm', 'uz_UZ');

  /// "12 345 678" — non-breaking thin-space grouping. Decimals are
  /// dropped: revenue rows always read as whole UZS.
  static String uzs(num value) {
    final formatted = _wholeUzs.format(value.round());
    return formatted.replaceAll(',', ' ').replaceAll('.', ' ');
  }

  /// "2.4M" / "812K" / raw integer for small numbers.
  static String compact(num value) {
    final v = value.toDouble();
    if (v.abs() >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return value.round().toString();
  }

  static String shortDate(DateTime d) => _shortMonth.format(d);
  static String monthYear(DateTime d) => _monthYear.format(d);

  /// "14:00" — used by the hourly chart axis labels and tooltip.
  static String hour(DateTime d) => _hour.format(d.toLocal());

  /// "5 daqiqa", "2 soat", "3 kun" oldin — used by the recent-reviews list
  /// so timestamps don't blow up the compact preview cards.
  static String relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'hozir';
    if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
    if (diff.inHours < 24) return '${diff.inHours} soat oldin';
    if (diff.inDays < 7) return '${diff.inDays} kun oldin';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} hafta oldin';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} oy oldin';
    return '${(diff.inDays / 365).floor()} yil oldin';
  }
}

/// Reusable white card with the analytics shadow. Children control padding
/// so charts can bleed to the edges while text blocks keep the standard
/// 16px inset.
class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
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

/// Section heading + optional trailing action (e.g. "Hammasi" link).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AnalyticsTokens.ink,
                letterSpacing: -0.3,
                height: 1.2,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Trend chip — "+12.4%" / "-3.1%" / "—" pill used next to every hero
/// number to show the period-over-period delta.
class TrendChip extends StatelessWidget {
  const TrendChip({super.key, required this.deltaPercent, this.tone});

  final double? deltaPercent;

  /// Optional override of the colour rule — used by metrics like
  /// "cancellation rate" where a downward delta is actually positive.
  final TrendTone? tone;

  @override
  Widget build(BuildContext context) {
    final delta = deltaPercent;
    if (delta == null) {
      return _ChipShell(
        background: const Color(0x14757575),
        foreground: AnalyticsTokens.grey,
        icon: Iconsax.minus,
        label: '—',
      );
    }
    final positive = delta >= 0;
    final good = tone == TrendTone.lowerIsBetter ? !positive : positive;
    final color = good ? AnalyticsTokens.positive : AnalyticsTokens.negative;
    return _ChipShell(
      background: color.withValues(alpha: 0.08),
      foreground: color,
      icon: positive ? Iconsax.trend_up : Iconsax.trend_down,
      label: '${positive ? '+' : ''}${delta.toStringAsFixed(1)}%',
    );
  }
}

enum TrendTone { higherIsBetter, lowerIsBetter }

class _ChipShell extends StatelessWidget {
  const _ChipShell({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini KPI card used by every tab's secondary KPI row.
class MiniKpiCard extends StatelessWidget {
  const MiniKpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AnalyticsTokens.positive;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AnalyticsTokens.grey,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              text: value,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AnalyticsTokens.ink,
                letterSpacing: -0.3,
                height: 1.1,
              ),
              children: [
                if (unit != null)
                  TextSpan(
                    text: '  $unit',
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AnalyticsTokens.greyMid,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Bu davr uchun ma'lumot yo'q" placeholder used by every chart card.
class SectionEmpty extends StatelessWidget {
  const SectionEmpty({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AnalyticsTokens.placeholderBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AnalyticsTokens.greyMid, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AnalyticsTokens.grey,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable hero metric block — caption above, big number + UZS unit
/// + trend chip on the same baseline. Used by every tab's top card.
class HeroMetric extends StatelessWidget {
  const HeroMetric({
    super.key,
    required this.caption,
    required this.value,
    required this.deltaPercent,
    this.unit,
    this.refreshing = false,
    this.tone,
  });

  final String caption;
  final String value;
  final String? unit;
  final double? deltaPercent;
  final bool refreshing;
  final TrendTone? tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                caption,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AnalyticsTokens.grey,
                  height: 1.2,
                ),
              ),
            ),
            if (refreshing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  valueColor: AlwaysStoppedAnimation(AnalyticsTokens.positive),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  text: value,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AnalyticsTokens.ink,
                    letterSpacing: -0.7,
                    height: 1.1,
                  ),
                  children: [
                    if (unit != null)
                      TextSpan(
                        text: '  $unit',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AnalyticsTokens.greyMid,
                          letterSpacing: 0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            TrendChip(deltaPercent: deltaPercent, tone: tone),
          ],
        ),
      ],
    );
  }
}

/// Tab bar — four pill buttons (sales / orders / reviews / customers).
class AnalyticsTabBar extends StatelessWidget {
  const AnalyticsTabBar({
    super.key,
    required this.activeIndex,
    required this.labels,
    required this.icons,
    required this.onChanged,
  });

  final int activeIndex;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == activeIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AnalyticsTokens.ink : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active
                      ? AnalyticsTokens.ink
                      : const Color(0xFFE5E5E5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icons[i],
                    size: 16,
                    color: active ? Colors.white : AnalyticsTokens.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: active ? Colors.white : AnalyticsTokens.grey,
                      letterSpacing: -0.1,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
