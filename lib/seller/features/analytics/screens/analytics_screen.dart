import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/analytics.dart';
import '../../../../shared/repositories/seller_analytics_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/error_state.dart';
import '../bloc/seller_analytics_cubit.dart';
import '../widgets/revenue_line_chart.dart';

// Local tokens — Plus Jakarta Sans is applied to every `Text` explicitly per
// the design spec rather than inheriting from the seller theme; this
// protects the screen from theme regressions.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _placeholderBg = Color(0xFFF1F1F1);
const _segmentBg = Color(0xFFEFEFEF);
const _negative = Color(0xFFDC2626);

// Donut palette — handpicked against the spec. Slices cycle through this
// list in order; the seller-side breakdown rarely exceeds 4-5 categories,
// so a small palette is enough.
const _donutPalette = <Color>[
  AppColors.terracotta,
  Color(0xFF2C3E50),
  Color(0xFFF39C12),
  Color(0xFF3949AB),
  Color(0xFF22C55E),
  Color(0xFFBDC3C7),
];

/// =====================================================================
/// Screen — premium analytics: range selector → hero chart → KPIs →
/// donut → top products. Backed entirely by [SellerAnalyticsCubit] /
/// [SellerAnalyticsRepository] — no mock data.
/// =====================================================================
class SellerAnalyticsScreen extends StatelessWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SellerAnalyticsCubit>(
      create: (_) => SellerAnalyticsCubit(sl<SellerAnalyticsRepository>())
        ..load(),
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<SellerAnalyticsCubit, SellerAnalyticsState>(
          builder: (context, state) {
            return Column(
              children: [
                const _AnalyticsHeader(),
                _RangeSelector(
                  value: state.range,
                  // Disable taps during the very first load — there's no
                  // snapshot to lay over, so a tap would just race the
                  // initial fetch.
                  enabled: !state.isInitialLoad,
                  onChanged: (r) =>
                      context.read<SellerAnalyticsCubit>().changeRange(r),
                ),
                Expanded(
                  child: _AnalyticsBody(state: state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.state});

  final SellerAnalyticsState state;

  @override
  Widget build(BuildContext context) {
    if (state.isInitialLoad) {
      return const _SkeletonBody();
    }
    if (state.status == SellerAnalyticsStatus.failure &&
        state.snapshot == null) {
      return ErrorState(
        message: state.error,
        onRetry: () => context.read<SellerAnalyticsCubit>().load(),
      );
    }

    final snapshot = state.effectiveSnapshot;
    return BrandRefreshIndicator(
      color: AppColors.sellerPrimary,
      onRefresh: () => context.read<SellerAnalyticsCubit>().refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          _SalesChartCard(snapshot: snapshot, refreshing: state.isReloading),
          const SizedBox(height: 14),
          _SecondaryKpiRow(snapshot: snapshot),
          const SizedBox(height: 24),
          _CategoryDistributionSection(snapshot: snapshot),
          const SizedBox(height: 24),
          _TopProductsSection(snapshot: snapshot),
        ],
      ),
    );
  }
}

// =============================================================================
// 1. Header
// =============================================================================
class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightBackground,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Analitika',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _ink,
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. Range selector — pill-shaped segmented control
// =============================================================================
class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final AnalyticsRange value;
  final ValueChanged<AnalyticsRange> onChanged;
  final bool enabled;

  static const _labels = <AnalyticsRange, String>{
    AnalyticsRange.d7: '7 kun',
    AnalyticsRange.d30: '30 kun',
    AnalyticsRange.m12: '12 oy',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _segmentBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            for (final r in AnalyticsRange.values)
              Expanded(
                child: _RangeSegment(
                  label: _labels[r] ?? r.name,
                  active: r == value,
                  onTap: enabled ? () => onChanged(r) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RangeSegment extends StatelessWidget {
  const _RangeSegment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.terracotta : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.terracotta.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : _grey,
            letterSpacing: -0.1,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 3. Hero sales chart card
// =============================================================================
class _SalesChartCard extends StatelessWidget {
  const _SalesChartCard({required this.snapshot, this.refreshing = false});

  final AnalyticsSnapshot snapshot;
  final bool refreshing;

  static const _captions = <AnalyticsRange, String>{
    AnalyticsRange.d7: "So'nggi 7 kun savdosi",
    AnalyticsRange.d30: "So'nggi 30 kun savdosi",
    AnalyticsRange.m12: "So'nggi 12 oy savdosi",
  };

  @override
  Widget build(BuildContext context) {
    final caption = _captions[snapshot.range] ?? "So'nggi davr savdosi";
    final values = snapshot.series.map((p) => p.revenue).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
      child: Column(
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
                    color: _grey,
                    height: 1.2,
                  ),
                ),
              ),
              if (refreshing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: BrandLoadingIndicator(radius: 7),
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
                    text: _NumberFmt.uzs(snapshot.totalRevenue),
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.7,
                      height: 1.1,
                    ),
                    children: [
                      TextSpan(
                        text: '  UZS',
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _greyMid,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TrendChip(deltaPercent: snapshot.deltaPercent),
            ],
          ),
          const SizedBox(height: 14),
          if (values.isEmpty)
            const _EmptyChart()
          else
            RevenueLineChart(values: values, height: 160),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.deltaPercent});

  /// `null` means "no comparison available" (previous period had zero
  /// revenue). Renders as a neutral em-dash rather than a misleading
  /// +100% / 0% chip.
  final double? deltaPercent;

  @override
  Widget build(BuildContext context) {
    final delta = deltaPercent;
    if (delta == null) {
      return _Chip(
        background: const Color(0x14757575),
        foreground: _grey,
        icon: Iconsax.minus,
        label: '—',
      );
    }
    final positive = delta >= 0;
    final color = positive ? AppColors.terracotta : _negative;
    return _Chip(
      background: color.withValues(alpha: 0.08),
      foreground: color,
      icon: positive ? Iconsax.trend_up : Iconsax.trend_down,
      label: '${positive ? '+' : ''}${delta.toStringAsFixed(1)}%',
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _placeholderBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.chart, size: 32, color: _greyMid),
          const SizedBox(height: 8),
          Text(
            "Bu davr uchun savdo yo'q",
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _grey,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 4. Secondary KPI row — Orders / Avg. order / Units sold (all real)
// =============================================================================
class _SecondaryKpiRow extends StatelessWidget {
  const _SecondaryKpiRow({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MiniKpiCard(
              icon: Iconsax.shopping_bag,
              label: 'Buyurtmalar',
              value: snapshot.ordersCount.toString(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniKpiCard(
              icon: Iconsax.receipt_2,
              label: "O'rtacha chek",
              value: _NumberFmt.compact(snapshot.avgOrderValue),
              unit: 'UZS',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniKpiCard(
              icon: Iconsax.box,
              label: 'Sotilgan',
              value: snapshot.unitsSold.toString(),
              unit: 'dona',
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniKpiCard extends StatelessWidget {
  const _MiniKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0x14C27A5F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.terracotta),
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
              color: _grey,
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
                color: _ink,
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
                      color: _greyMid,
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

// =============================================================================
// 5. Category donut + legend
// =============================================================================
class _CategoryDistributionSection extends StatelessWidget {
  const _CategoryDistributionSection({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final slices = snapshot.categoryBreakdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sotuvlar tarkibi',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.3,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
          child: slices.isEmpty
              ? _SectionEmpty(
                  icon: Iconsax.chart_2,
                  message: "Kategoriya bo'yicha ma'lumot yo'q",
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: _CategoryDonut(slices: slices),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < slices.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _LegendRow(
                              slice: slices[i],
                              color: _donutPalette[i % _donutPalette.length],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.slices});

  final List<CategorySlice> slices;

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 38,
        startDegreeOffset: -90,
        borderData: FlBorderData(show: false),
        sections: [
          for (var i = 0; i < slices.length; i++)
            PieChartSectionData(
              value: slices[i].percent,
              color: _donutPalette[i % _donutPalette.length],
              radius: 22,
              showTitle: false,
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.color});

  final CategorySlice slice;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            slice.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _ink,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${slice.percent.toStringAsFixed(0)}%',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _ink,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 6. Top products
// =============================================================================
class _TopProductsSection extends StatelessWidget {
  const _TopProductsSection({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final products = snapshot.topProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top mahsulotlar',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.3,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _SectionEmpty(
              icon: Iconsax.box,
              message: "Hali sotilgan mahsulot yo'q",
            ),
          )
        else
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _TopProductTile(product: products[i]),
          ),
      ],
    );
  }
}

class _TopProductTile extends StatelessWidget {
  const _TopProductTile({required this.product});

  final TopProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          const ColoredBox(color: _placeholderBg),
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: _placeholderBg,
                        child: Icon(Iconsax.image, color: _greyMid, size: 22),
                      ),
                    )
                  : const ColoredBox(
                      color: _placeholderBg,
                      child: Icon(Iconsax.image, color: _greyMid, size: 22),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.unitsSold} dona sotildi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
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
          RichText(
            textAlign: TextAlign.end,
            text: TextSpan(
              text: _NumberFmt.uzs(product.revenue),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.2,
                height: 1.2,
              ),
              children: [
                TextSpan(
                  text: '  UZS',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _greyMid,
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

// =============================================================================
// Section empty state — used by the donut + top-products cards.
// =============================================================================
class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.icon, required this.message});

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
              color: _placeholderBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _greyMid, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _grey,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Skeleton — shown on the very first load (no prior snapshot to lay over).
// =============================================================================
class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SkeletonCard(height: 220),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: _SkeletonCard(height: 96)),
            SizedBox(width: 10),
            Expanded(child: _SkeletonCard(height: 96)),
            SizedBox(width: 10),
            Expanded(child: _SkeletonCard(height: 96)),
          ],
        ),
        const SizedBox(height: 24),
        _SkeletonCard(height: 170),
        const SizedBox(height: 24),
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _SkeletonCard(height: 76),
        ],
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
    );
  }
}

// =============================================================================
// Number formatting helpers — kept local since this is the only place that
// renders UZS with thousands separators and a compact ("2.4M") form.
// =============================================================================
class _NumberFmt {
  _NumberFmt._();

  static final _wholeUzs = NumberFormat('#,##0', 'uz_UZ');

  /// "12 345 678" — non-breaking thin-space grouping. Decimals are
  /// dropped: revenue rows always read as whole UZS.
  static String uzs(num value) {
    final formatted = _wholeUzs.format(value.round());
    // Replace the locale's grouping char with a thin space so the result
    // matches the design's typography regardless of system locale.
    return formatted.replaceAll(',', ' ').replaceAll('.', ' ');
  }

  /// "2.4M" / "812K" / raw integer for small numbers. Used by the
  /// avg-order-value KPI where the full number would overflow the
  /// 1/3-width card.
  static String compact(num value) {
    final v = value.toDouble();
    if (v.abs() >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return value.round().toString();
  }
}
