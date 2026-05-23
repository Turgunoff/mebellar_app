import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/analytics.dart';
import '../../../../shared/models/order_status.dart';
import 'analytics_common.dart';
import 'revenue_line_chart.dart';

/// "Buyurtmalar" tab — fulfilment view. Shows order volume, the per-status
/// donut, completion / cancellation rates, and a small "by status" list.
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key, required this.snapshot, required this.refreshing});

  final AnalyticsSnapshot snapshot;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final orders = snapshot.orders;
    final granularity = snapshot.filter.granularityFor(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _OrdersHeroCard(
          orders: orders,
          granularity: granularity,
          refreshing: refreshing,
        ),
        const SizedBox(height: 14),
        _OrdersKpiRow(orders: orders),
        const SizedBox(height: 24),
        _StatusBreakdownCard(orders: orders),
      ],
    );
  }
}

class _OrdersHeroCard extends StatelessWidget {
  const _OrdersHeroCard({
    required this.orders,
    required this.granularity,
    required this.refreshing,
  });

  final OrdersBreakdown orders;
  final BucketGranularity granularity;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final values = orders.series.map((p) => p.count.toDouble() as num).toList();
    final dates = orders.series.map((p) => p.bucketStart).toList();
    return AnalyticsCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroMetric(
            caption: 'Davr ichidagi buyurtmalar',
            value: orders.total.toString(),
            unit: 'dona',
            deltaPercent: orders.deltaPercent,
            refreshing: refreshing,
          ),
          const SizedBox(height: 14),
          if (values.isEmpty || values.every((v) => v == 0))
            _ChartPlaceholder(message: "Buyurtmalar yo'q")
          else
            RevenueLineChart(
              values: values,
              dates: dates,
              granularity: granularity,
              valueFormatter: (v) => v.round().toString(),
              unit: 'dona',
              height: 160,
            ),
        ],
      ),
    );
  }
}

class _OrdersKpiRow extends StatelessWidget {
  const _OrdersKpiRow({required this.orders});

  final OrdersBreakdown orders;

  @override
  Widget build(BuildContext context) {
    final completion = orders.completionRate;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MiniKpiCard(
              icon: Iconsax.tick_circle,
              label: 'Yetkazilgan',
              value: orders.deliveredCount.toString(),
              color: AnalyticsTokens.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MiniKpiCard(
              icon: Iconsax.timer_1,
              label: 'Faol',
              value: orders.activeCount.toString(),
              color: AnalyticsTokens.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MiniKpiCard(
              icon: Iconsax.close_circle,
              label: 'Bekor',
              value: orders.cancelledCount.toString(),
              color: AnalyticsTokens.negative,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MiniKpiCard(
              icon: Iconsax.percentage_circle,
              label: 'Bajarish',
              value: completion == null
                  ? '—'
                  : '${completion.toStringAsFixed(0)}%',
              color: AnalyticsTokens.info,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({required this.orders});

  final OrdersBreakdown orders;

  @override
  Widget build(BuildContext context) {
    final slices = orders.byStatus;
    final cancel = orders.cancellationRate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Status boʼyicha'),
        AnalyticsCard(
          child: slices.isEmpty
              ? SectionEmpty(
                  icon: Iconsax.chart_2,
                  message: "Bu davr uchun buyurtma yo'q",
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: _StatusDonut(slices: slices),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < slices.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                _StatusLegend(
                                  slice: slices[i],
                                  color: _statusColor(slices[i].status, i),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (cancel != null) ...[
                      const Divider(height: 24, color: Color(0xFFEFEFEF)),
                      Row(
                        children: [
                          const Icon(
                            Iconsax.warning_2,
                            size: 16,
                            color: AnalyticsTokens.negative,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Bekor qilingan buyurtmalar ulushi",
                              style: TextStyle(
                                fontFamily: AppFonts.seller,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AnalyticsTokens.grey,
                              ),
                            ),
                          ),
                          Text(
                            '${cancel.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontFamily: AppFonts.seller,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AnalyticsTokens.negative,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _StatusDonut extends StatelessWidget {
  const _StatusDonut({required this.slices});

  final List<StatusSlice> slices;

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
              value: slices[i].percent == 0 ? 0.01 : slices[i].percent,
              color: _statusColor(slices[i].status, i),
              radius: 22,
              showTitle: false,
            ),
        ],
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend({required this.slice, required this.color});

  final StatusSlice slice;
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
            _statusLabel(slice.status),
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
          '${slice.count}',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AnalyticsTokens.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '(${slice.percent.toStringAsFixed(0)}%)',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AnalyticsTokens.grey,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// Maps a backend status code to its display colour. Falls back to the
/// palette by index when the status is unknown so the donut still paints.
Color _statusColor(String status, int index) {
  switch (status) {
    case 'delivered':
      return AnalyticsTokens.success;
    case 'cancelled':
      return AnalyticsTokens.negative;
    case 'shipped':
      return AnalyticsTokens.info;
    case 'preparing':
      return const Color(0xFF8E44AD);
    case 'confirmed':
      return const Color(0xFF14B8A6);
    case 'pending':
      return AnalyticsTokens.warning;
    default:
      return AnalyticsTokens
          .chartPalette[index % AnalyticsTokens.chartPalette.length];
  }
}

String _statusLabel(String code) {
  return switch (OrderStatus.fromCode(code)) {
    OrderStatus.pending => 'Kutilmoqda',
    OrderStatus.confirmed => 'Tasdiqlangan',
    OrderStatus.preparing => 'Tayyorlanmoqda',
    OrderStatus.shipped => 'Yoʼlda',
    OrderStatus.delivered => 'Yetkazilgan',
    OrderStatus.cancelled => 'Bekor qilingan',
  };
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AnalyticsTokens.placeholderBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.shopping_bag,
              size: 32, color: AnalyticsTokens.greyMid),
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
