import 'package:equatable/equatable.dart';

/// Time-window selector used across the analytics surface.
///
/// Each range bundles two pieces of view-model info:
///   * [days] — the underlying SQL window (for `created_at >= now() - days`).
///   * [buckets] — how many points the revenue chart paints. 7d / 30d
///     bucket by day; 12mo buckets by month so the chart stays readable.
///
/// `previousWindow()` returns the immediately-preceding window of the
/// same length, used to compute "vs. previous period" deltas.
enum AnalyticsRange {
  d7(days: 7, buckets: 7),
  d30(days: 30, buckets: 30),
  m12(days: 365, buckets: 12);

  const AnalyticsRange({required this.days, required this.buckets});

  final int days;
  final int buckets;

  /// `true` when the chart should bucket by month rather than by day. Only
  /// the 12-month range crosses that threshold.
  bool get isMonthly => this == AnalyticsRange.m12;

  /// Inclusive start / exclusive end of the current window relative to
  /// [now]. Truncated to UTC midnight so consecutive calls within the
  /// same day land on the same bucket boundary.
  AnalyticsWindow currentWindow(DateTime now) {
    final endExclusive = _startOfNextDay(now);
    final start = endExclusive.subtract(Duration(days: days));
    return AnalyticsWindow(start: start, endExclusive: endExclusive);
  }

  /// The window immediately preceding [currentWindow] of the same length.
  /// Used to compute the comparison delta the trend chip renders.
  AnalyticsWindow previousWindow(DateTime now) {
    final cur = currentWindow(now);
    final start = cur.start.subtract(Duration(days: days));
    return AnalyticsWindow(start: start, endExclusive: cur.start);
  }

  static DateTime _startOfNextDay(DateTime now) {
    final utc = now.toUtc();
    final today = DateTime.utc(utc.year, utc.month, utc.day);
    return today.add(const Duration(days: 1));
  }
}

class AnalyticsWindow extends Equatable {
  const AnalyticsWindow({required this.start, required this.endExclusive});

  /// Inclusive lower bound (UTC).
  final DateTime start;

  /// Exclusive upper bound (UTC) — use `<` not `<=` when filtering.
  final DateTime endExclusive;

  /// `true` when [timestamp] falls within `[start, endExclusive)`.
  bool contains(DateTime timestamp) {
    final utc = timestamp.toUtc();
    return !utc.isBefore(start) && utc.isBefore(endExclusive);
  }

  @override
  List<Object?> get props => [start, endExclusive];
}

/// One bucket of revenue used by the hero line chart.
class RevenuePoint extends Equatable {
  const RevenuePoint({required this.bucketStart, required this.revenue});

  final DateTime bucketStart;
  final num revenue;

  @override
  List<Object?> get props => [bucketStart, revenue];
}

/// Best-selling product row used by the "Top mahsulotlar" list.
class TopProduct extends Equatable {
  const TopProduct({
    required this.productId,
    required this.name,
    required this.unitsSold,
    required this.revenue,
    this.imageUrl,
  });

  final String productId;
  final String name;
  final int unitsSold;
  final num revenue;
  final String? imageUrl;

  @override
  List<Object?> get props => [productId, unitsSold, revenue];
}

/// One slice of the donut chart — revenue rolled up to a category.
class CategorySlice extends Equatable {
  const CategorySlice({
    required this.categoryId,
    required this.label,
    required this.revenue,
    required this.percent,
  });

  /// `null` for items whose product has no category — the slice is still
  /// rendered but labelled "Boshqa".
  final String? categoryId;
  final String label;
  final num revenue;

  /// `percent` always falls in `[0, 100]`. Computed from the snapshot's
  /// total revenue so all slices sum to 100 (minus rounding).
  final double percent;

  @override
  List<Object?> get props => [categoryId, label, revenue];
}

/// The full analytics snapshot the screen renders. One instance per
/// (range, fetch) and entirely self-contained — the screen does no
/// further aggregation.
class AnalyticsSnapshot extends Equatable {
  const AnalyticsSnapshot({
    required this.range,
    required this.totalRevenue,
    required this.previousRevenue,
    required this.ordersCount,
    required this.unitsSold,
    required this.avgOrderValue,
    required this.series,
    required this.topProducts,
    required this.categoryBreakdown,
  });

  final AnalyticsRange range;
  final num totalRevenue;
  final num previousRevenue;
  final int ordersCount;
  final int unitsSold;
  final num avgOrderValue;
  final List<RevenuePoint> series;
  final List<TopProduct> topProducts;
  final List<CategorySlice> categoryBreakdown;

  /// Empty snapshot for the "no data yet" state. Avoids littering the
  /// view layer with null-checks on every field.
  factory AnalyticsSnapshot.empty(AnalyticsRange range) => AnalyticsSnapshot(
        range: range,
        totalRevenue: 0,
        previousRevenue: 0,
        ordersCount: 0,
        unitsSold: 0,
        avgOrderValue: 0,
        series: const [],
        topProducts: const [],
        categoryBreakdown: const [],
      );

  /// Period-over-period delta as a percent. Returns `null` (rather than
  /// `infinity` or `0`) when the previous window's revenue was zero, so
  /// the chip can render "—" instead of a misleading +100% / 0%.
  double? get deltaPercent {
    if (previousRevenue == 0) return null;
    return (totalRevenue - previousRevenue) / previousRevenue * 100;
  }

  bool get isEmpty => totalRevenue == 0 && ordersCount == 0 && series.isEmpty;

  @override
  List<Object?> get props => [
        range,
        totalRevenue,
        previousRevenue,
        ordersCount,
        unitsSold,
        avgOrderValue,
        series,
        topProducts,
        categoryBreakdown,
      ];
}
