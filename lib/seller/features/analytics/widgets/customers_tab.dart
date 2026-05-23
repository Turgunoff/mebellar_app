import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/analytics.dart';
import 'analytics_common.dart';

/// "Mijozlar" tab — unique customer count + new/returning split + top
/// spenders. Light on charts on purpose: the data here reads better as
/// KPI tiles and a ranked list than as a time-series.
class CustomersTab extends StatelessWidget {
  const CustomersTab({
    super.key,
    required this.snapshot,
    required this.refreshing,
  });

  final AnalyticsSnapshot snapshot;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final customers = snapshot.customers;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _CustomersHero(customers: customers, refreshing: refreshing),
        const SizedBox(height: 14),
        _CustomersKpiRow(customers: customers),
        const SizedBox(height: 24),
        _SegmentationCard(customers: customers),
        const SizedBox(height: 24),
        _TopCustomersSection(customers: customers),
      ],
    );
  }
}

class _CustomersHero extends StatelessWidget {
  const _CustomersHero({required this.customers, required this.refreshing});

  final CustomersBreakdown customers;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return AnalyticsCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: HeroMetric(
        caption: 'Davr ichidagi mijozlar',
        value: customers.unique.toString(),
        unit: 'kishi',
        deltaPercent: customers.deltaPercent,
        refreshing: refreshing,
      ),
    );
  }
}

class _CustomersKpiRow extends StatelessWidget {
  const _CustomersKpiRow({required this.customers});

  final CustomersBreakdown customers;

  @override
  Widget build(BuildContext context) {
    final returning = customers.returningShare;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MiniKpiCard(
              icon: Iconsax.user_add,
              label: 'Yangi',
              value: customers.newCustomers.toString(),
              color: AnalyticsTokens.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MiniKpiCard(
              icon: Iconsax.refresh_2,
              label: 'Qaytgan',
              value: customers.returningCustomers.toString(),
              color: AnalyticsTokens.info,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MiniKpiCard(
              icon: Iconsax.percentage_circle,
              label: 'Qaytish %',
              value: returning == null
                  ? '—'
                  : '${returning.toStringAsFixed(0)}%',
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentationCard extends StatelessWidget {
  const _SegmentationCard({required this.customers});

  final CustomersBreakdown customers;

  @override
  Widget build(BuildContext context) {
    final total = customers.unique;
    if (total == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Segmentlar'),
          AnalyticsCard(
            child: SectionEmpty(
              icon: Iconsax.profile_2user,
              message: "Bu davr uchun mijoz yo'q",
            ),
          ),
        ],
      );
    }
    final newRatio = customers.newCustomers / total;
    final returningRatio = customers.returningCustomers / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Segmentlar'),
        AnalyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (newRatio * 1000).round().clamp(1, 1000),
                        child: Container(color: AnalyticsTokens.success),
                      ),
                      Expanded(
                        flex: (returningRatio * 1000).round().clamp(1, 1000),
                        child: Container(color: AnalyticsTokens.info),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SegmentLegendRow(
                color: AnalyticsTokens.success,
                label: 'Yangi mijozlar',
                count: customers.newCustomers,
                percent: newRatio * 100,
              ),
              const SizedBox(height: 10),
              _SegmentLegendRow(
                color: AnalyticsTokens.info,
                label: 'Qaytgan mijozlar',
                count: customers.returningCustomers,
                percent: returningRatio * 100,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentLegendRow extends StatelessWidget {
  const _SegmentLegendRow({
    required this.color,
    required this.label,
    required this.count,
    required this.percent,
  });

  final Color color;
  final String label;
  final int count;
  final double percent;

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
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AnalyticsTokens.ink,
            ),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AnalyticsTokens.ink,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '(${percent.toStringAsFixed(0)}%)',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AnalyticsTokens.grey,
          ),
        ),
      ],
    );
  }
}

class _TopCustomersSection extends StatelessWidget {
  const _TopCustomersSection({required this.customers});

  final CustomersBreakdown customers;

  @override
  Widget build(BuildContext context) {
    final list = customers.topCustomers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Top mijozlar'),
        if (list.isEmpty)
          AnalyticsCard(
            child: SectionEmpty(
              icon: Iconsax.crown_1,
              message: "Hozircha mijozlar yo'q",
            ),
          )
        else
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _TopCustomerTile(
              index: i,
              customer: list[i],
            ),
          ),
      ],
    );
  }
}

class _TopCustomerTile extends StatelessWidget {
  const _TopCustomerTile({required this.index, required this.customer});

  final int index;
  final TopCustomer customer;

  @override
  Widget build(BuildContext context) {
    return AnalyticsCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == 0
                  ? const Color(0x33F59E0B)
                  : AnalyticsTokens.placeholderBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#${index + 1}',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: index == 0
                    ? const Color(0xFFB45309)
                    : AnalyticsTokens.grey,
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
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AnalyticsTokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${customer.ordersCount} ta buyurtma',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AnalyticsTokens.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            textAlign: TextAlign.end,
            text: TextSpan(
              text: AnalyticsFmt.uzs(customer.totalSpent),
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AnalyticsTokens.ink,
              ),
              children: [
                TextSpan(
                  text: '  UZS',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AnalyticsTokens.greyMid,
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
