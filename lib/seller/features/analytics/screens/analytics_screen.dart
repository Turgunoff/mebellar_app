import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/revenue_line_chart.dart';

// Local tokens — Plus Jakarta Sans is applied to every `Text`
// explicitly per the design spec rather than inheriting from the
// seller theme; this protects the screen from theme regressions.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _placeholderBg = Color(0xFFF1F1F1);
const _segmentBg = Color(0xFFEFEFEF);
const _positive = Color(0xFF1F9D55);

// Donut palette — handpicked against the spec; keep these locked
// instead of pulling from theme so the legend swatches and slices
// stay in sync regardless of theme tweaks.
const _catSoft = AppColors.terracotta;
const _catBedroom = Color(0xFF2C3E50);
const _catKitchen = Color(0xFFF39C12);
const _catOther = Color(0xFFBDC3C7);

enum _Range { d7, d30, m12 }

extension _RangeLabel on _Range {
  String get label => switch (this) {
        _Range.d7 => '7 kun',
        _Range.d30 => '30 kun',
        _Range.m12 => '12 oy',
      };
}

// =============================================================================
// Screen — premium analytics: range selector → hero chart → KPIs → donut → top
// =============================================================================
class SellerAnalyticsScreen extends StatefulWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  State<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends State<SellerAnalyticsScreen> {
  _Range _range = _Range.d30;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _AnalyticsHeader(),
            _RangeSelector(
              value: _range,
              onChanged: (r) => setState(() => _range = r),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  _SalesChartCard(range: _range),
                  const SizedBox(height: 14),
                  const _SecondaryKpiRow(),
                  const SizedBox(height: 24),
                  const _CategoryDistributionSection(),
                  const SizedBox(height: 24),
                  const _TopProductsHeader(),
                  const SizedBox(height: 12),
                  const _TopProductsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 1. Header — "Analitika" title in bold Jakarta
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
              style: TextStyle(fontFamily: AppFonts.seller, 
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
// 2. Range selector — pill-shaped segmented control, terracotta active
// =============================================================================
class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});

  final _Range value;
  final ValueChanged<_Range> onChanged;

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
            for (final r in _Range.values)
              Expanded(child: _RangeSegment(
                label: r.label,
                active: r == value,
                onTap: () => onChanged(r),
              )),
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
  final VoidCallback onTap;

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
          style: TextStyle(fontFamily: AppFonts.seller, 
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
// 3. Sales chart card — title, hero number, trend chip, terracotta curve
// =============================================================================
class _SalesChartCard extends StatelessWidget {
  const _SalesChartCard({required this.range});

  final _Range range;

  @override
  Widget build(BuildContext context) {
    final series = switch (range) {
      _Range.d7 => _kSeries7,
      _Range.d30 => _kSeries30,
      _Range.m12 => _kSeries12,
    };
    final total = switch (range) {
      _Range.d7 => '8 940 000',
      _Range.d30 => '37 372 000',
      _Range.m12 => '412 800 000',
    };
    final delta = switch (range) {
      _Range.d7 => '+8.1%',
      _Range.d30 => '+12.4%',
      _Range.m12 => '+24.8%',
    };
    final caption = switch (range) {
      _Range.d7 => "So'nggi 7 kun savdosi",
      _Range.d30 => "So'nggi 30 kun savdosi",
      _Range.m12 => "So'nggi 12 oy savdosi",
    };

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
          Text(
            caption,
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _grey,
              height: 1.2,
            ),
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
                    text: total,
                    style: TextStyle(fontFamily: AppFonts.seller, 
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.7,
                      height: 1.1,
                    ),
                    children: [
                      TextSpan(
                        text: '  UZS',
                        style: TextStyle(fontFamily: AppFonts.seller, 
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
              _TrendChip(label: delta),
            ],
          ),
          const SizedBox(height: 14),
          RevenueLineChart(values: series, height: 160),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x14C27A5F), // terracotta @ ~8%
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Iconsax.trend_up,
            size: 14,
            color: AppColors.terracotta,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontFamily: AppFonts.seller, 
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.terracotta,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 4. Secondary KPI row — Views / Conversion / Avg. order
// =============================================================================
class _SecondaryKpiRow extends StatelessWidget {
  const _SecondaryKpiRow();

  @override
  Widget build(BuildContext context) {
    // `IntrinsicHeight` lets `stretch` work inside the ListView's
    // unbounded vertical axis: it gives the Row a finite height
    // (the tallest child's intrinsic height), which is then handed
    // back down so every card matches that height.
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MiniKpiCard(
              icon: Iconsax.eye,
              label: "Ko'rishlar",
              value: '1 245',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _MiniKpiCard(
              icon: Iconsax.flash_1,
              label: 'Konversiya',
              value: '3.2%',
              delta: '+0.3%',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _MiniKpiCard(
              icon: Iconsax.receipt_2,
              label: "O'rtacha chek",
              value: '2.4M',
              unit: 'UZS',
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
    this.delta,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? delta;

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
            style: TextStyle(fontFamily: AppFonts.seller, 
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
              style: TextStyle(fontFamily: AppFonts.seller, 
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
                    style: TextStyle(fontFamily: AppFonts.seller, 
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _greyMid,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(
              delta!,
              style: TextStyle(fontFamily: AppFonts.seller, 
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _positive,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// 5. Category distribution — donut chart with legend
// =============================================================================
class _CategoryDistributionSection extends StatelessWidget {
  const _CategoryDistributionSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sotuvlar tarkibi',
          style: TextStyle(fontFamily: AppFonts.seller, 
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 130,
                height: 130,
                child: _CategoryDonut(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _kCategories.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _LegendRow(slice: _kCategories[i]),
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
  const _CategoryDonut();

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 38,
        startDegreeOffset: -90,
        borderData: FlBorderData(show: false),
        sections: [
          for (final c in _kCategories)
            PieChartSectionData(
              value: c.percent,
              color: c.color,
              radius: 22,
              showTitle: false,
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice});

  final _CategorySlice slice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: slice.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            slice.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: AppFonts.seller, 
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
          style: TextStyle(fontFamily: AppFonts.seller, 
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
// 6. Top products section
// =============================================================================
class _TopProductsHeader extends StatelessWidget {
  const _TopProductsHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Top mahsulotlar',
      style: TextStyle(fontFamily: AppFonts.seller, 
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: _ink,
        letterSpacing: -0.3,
        height: 1.2,
      ),
    );
  }
}

class _TopProductsList extends StatelessWidget {
  const _TopProductsList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _kTopProducts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TopProductTile(product: _kTopProducts[i]),
    );
  }
}

class _TopProductTile extends StatelessWidget {
  const _TopProductTile({required this.product});

  final _MockProduct product;

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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _placeholderBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Iconsax.image,
              size: 22,
              color: _greyMid,
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
                  style: TextStyle(fontFamily: AppFonts.seller, 
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
                  style: TextStyle(fontFamily: AppFonts.seller, 
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
              text: product.revenueLabel,
              style: TextStyle(fontFamily: AppFonts.seller, 
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.2,
                height: 1.2,
              ),
              children: [
                TextSpan(
                  text: '  UZS',
                  style: TextStyle(fontFamily: AppFonts.seller, 
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
// Mock data
// =============================================================================
@immutable
class _MockProduct {
  const _MockProduct({
    required this.name,
    required this.unitsSold,
    required this.revenueLabel,
  });

  final String name;
  final int unitsSold;
  final String revenueLabel;
}

@immutable
class _CategorySlice {
  const _CategorySlice({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final double percent;
  final Color color;
}

const _kCategories = <_CategorySlice>[
  _CategorySlice(label: 'Yumshoq mebellar', percent: 45, color: _catSoft),
  _CategorySlice(label: 'Yotoqxona', percent: 30, color: _catBedroom),
  _CategorySlice(label: 'Oshxona', percent: 15, color: _catKitchen),
  _CategorySlice(label: 'Boshqa', percent: 10, color: _catOther),
];

const _kTopProducts = <_MockProduct>[
  _MockProduct(
    name: 'Klassik kuxnya jihozlari',
    unitsSold: 12,
    revenueLabel: '11 600 000',
  ),
  _MockProduct(
    name: '2 kishilik karavot "Verona"',
    unitsSold: 4,
    revenueLabel: '23 200 000',
  ),
  _MockProduct(
    name: 'Burchakli divan "Loft"',
    unitsSold: 2,
    revenueLabel: '17 000 000',
  ),
  _MockProduct(
    name: 'Velvet kresla',
    unitsSold: 6,
    revenueLabel: '11 100 000',
  ),
];

// Mock revenue series — gentle upward trends so the curve has a
// natural shape regardless of which range is selected.
const _kSeries7 = <num>[820, 1020, 940, 1180, 1340, 1490, 1620];

const _kSeries30 = <num>[
  640, 720, 880, 760, 540, 480, 920,
  1050, 980, 1120, 1240, 980, 760, 1340,
  1280, 1410, 1320, 1180, 980, 1450, 1620,
  1580, 1480, 1390, 1240, 1520, 1740, 1890,
  1820, 1960,
];

const _kSeries12 = <num>[
  18, 22, 19, 25, 28, 31, 27, 32, 36, 41, 38, 45,
];
