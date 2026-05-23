import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/analytics.dart';
import 'analytics_common.dart';
import 'revenue_line_chart.dart';

/// "Sotuvlar" tab — revenue hero + KPIs + category donut + top products.
/// Composed in a single file rather than a per-widget file: the layout is
/// linear and the widgets are not reused outside this tab.
class SalesTab extends StatelessWidget {
  const SalesTab({super.key, required this.snapshot, required this.refreshing});

  final AnalyticsSnapshot snapshot;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _SalesChartCard(snapshot: snapshot, refreshing: refreshing),
        const SizedBox(height: 14),
        _SecondaryKpiRow(snapshot: snapshot),
        const SizedBox(height: 24),
        _CategoryDistributionSection(snapshot: snapshot),
        const SizedBox(height: 24),
        _TopProductsSection(snapshot: snapshot),
      ],
    );
  }
}

class _SalesChartCard extends StatelessWidget {
  const _SalesChartCard({required this.snapshot, required this.refreshing});

  final AnalyticsSnapshot snapshot;
  final bool refreshing;

  static const _captions = <AnalyticsRange, String>{
    AnalyticsRange.today: "Bugungi savdo",
    AnalyticsRange.d7: "So'nggi 7 kun savdosi",
    AnalyticsRange.d30: "So'nggi 30 kun savdosi",
    AnalyticsRange.d90: "So'nggi 90 kun savdosi",
    AnalyticsRange.m12: "So'nggi 12 oy savdosi",
    AnalyticsRange.custom: "Tanlangan davr savdosi",
  };

  @override
  Widget build(BuildContext context) {
    final caption = _captions[snapshot.range] ?? "So'nggi davr savdosi";
    final values = snapshot.series.map((p) => p.revenue).toList();
    final dates = snapshot.series.map((p) => p.bucketStart).toList();
    final granularity = snapshot.filter.granularityFor(DateTime.now());
    return AnalyticsCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroMetric(
            caption: caption,
            value: AnalyticsFmt.uzs(snapshot.totalRevenue),
            unit: 'UZS',
            deltaPercent: snapshot.deltaPercent,
            refreshing: refreshing,
          ),
          const SizedBox(height: 14),
          if (values.isEmpty)
            const _ChartEmpty(message: "Bu davr uchun savdo yo'q")
          else
            RevenueLineChart(
              values: values,
              dates: dates,
              granularity: granularity,
              valueFormatter: (v) => AnalyticsFmt.uzs(v),
              unit: 'UZS',
              height: 180,
            ),
        ],
      ),
    );
  }
}

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
            child: MiniKpiCard(
              icon: Iconsax.shopping_bag,
              label: 'Buyurtmalar',
              value: snapshot.ordersCount.toString(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MiniKpiCard(
              icon: Iconsax.receipt_2,
              label: "O'rtacha chek",
              value: AnalyticsFmt.compact(snapshot.avgOrderValue),
              unit: 'UZS',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MiniKpiCard(
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

class _CategoryDistributionSection extends StatelessWidget {
  const _CategoryDistributionSection({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final slices = snapshot.categoryBreakdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Sotuvlar tarkibi'),
        AnalyticsCard(
          child: slices.isEmpty
              ? SectionEmpty(
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
                              color: AnalyticsTokens.chartPalette[
                                  i % AnalyticsTokens.chartPalette.length],
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
              color: AnalyticsTokens
                  .chartPalette[i % AnalyticsTokens.chartPalette.length],
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
              color: AnalyticsTokens.ink,
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
            color: AnalyticsTokens.ink,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _TopProductsSection extends StatelessWidget {
  const _TopProductsSection({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final products = snapshot.topProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Top mahsulotlar'),
        if (products.isEmpty)
          AnalyticsCard(
            child: SectionEmpty(
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
                          const ColoredBox(color: AnalyticsTokens.placeholderBg),
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: AnalyticsTokens.placeholderBg,
                        child: Icon(Iconsax.image,
                            color: AnalyticsTokens.greyMid, size: 22),
                      ),
                    )
                  : const ColoredBox(
                      color: AnalyticsTokens.placeholderBg,
                      child: Icon(Iconsax.image,
                          color: AnalyticsTokens.greyMid, size: 22),
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
                    color: AnalyticsTokens.ink,
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
                    color: AnalyticsTokens.grey,
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
              text: AnalyticsFmt.uzs(product.revenue),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AnalyticsTokens.ink,
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

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AnalyticsTokens.placeholderBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.chart, size: 32, color: AnalyticsTokens.greyMid),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AnalyticsTokens.grey,
            ),
          ),
        ],
      ),
    );
  }
}
