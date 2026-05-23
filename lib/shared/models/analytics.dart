import 'package:equatable/equatable.dart';

/// How the time-series chart buckets its data. Each value carries enough
/// info for the repository to pick the right bucket key (UTC truncation
/// to hour / day / month) and for the chart to label the x-axis.
enum BucketGranularity {
  hour,
  day,
  month;

  bool get isHourly => this == BucketGranularity.hour;
  bool get isMonthly => this == BucketGranularity.month;
}

/// Pre-set time windows the seller can switch between.
///
/// Each preset bundles three view-model bits:
///   * [days] — the underlying SQL window. `null` for [custom] (the filter
///     supplies its own start/end).
///   * [buckets] — how many points the chart paints. Day-grained for
///     d7/d30/d90, hour-grained for [today], month-grained for [m12].
///   * [granularity] — bucket size; `null` for custom (auto-picked from
///     the resolved window length).
enum AnalyticsRange {
  today(days: 1, buckets: 24, granularity: BucketGranularity.hour),
  d7(days: 7, buckets: 7, granularity: BucketGranularity.day),
  d30(days: 30, buckets: 30, granularity: BucketGranularity.day),
  d90(days: 90, buckets: 90, granularity: BucketGranularity.day),
  m12(days: 365, buckets: 12, granularity: BucketGranularity.month),
  custom(days: null, buckets: null, granularity: null);

  const AnalyticsRange({
    required this.days,
    required this.buckets,
    required this.granularity,
  });

  final int? days;
  final int? buckets;
  final BucketGranularity? granularity;

  /// `true` when the chart should bucket by month rather than by day/hour.
  /// Kept as a convenience getter for callers that only care about the
  /// month/non-month branch.
  bool get isMonthly => granularity?.isMonthly ?? false;
}

/// The four high-level analytics views. Pivots the screen between
/// revenue, fulfilment, customer-voice and customer-spend metrics.
enum AnalyticsTab {
  sales,
  orders,
  reviews,
  customers,
}

/// Resolved filter handed to the repository. Holds the active preset plus
/// the optional custom-range bounds — both pieces live in one value so the
/// cubit state stays a single `==`-comparable object.
class AnalyticsFilter extends Equatable {
  const AnalyticsFilter({
    this.range = AnalyticsRange.d30,
    this.customStart,
    this.customEnd,
  });

  final AnalyticsRange range;

  /// Inclusive start of the custom window, in the seller's local clock.
  /// Ignored unless [range] is [AnalyticsRange.custom].
  final DateTime? customStart;

  /// Inclusive end of the custom window. Ignored unless [range] is
  /// [AnalyticsRange.custom].
  final DateTime? customEnd;

  AnalyticsFilter copyWith({
    AnalyticsRange? range,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCustom = false,
  }) {
    return AnalyticsFilter(
      range: range ?? this.range,
      customStart: clearCustom ? null : (customStart ?? this.customStart),
      customEnd: clearCustom ? null : (customEnd ?? this.customEnd),
    );
  }

  /// Resolves the inclusive-start / exclusive-end window relative to [now].
  /// Truncated to UTC midnight so consecutive calls inside the same day
  /// land on the same bucket boundary.
  AnalyticsWindow windowFor(DateTime now) {
    final endExclusive = _startOfNextDay(now);
    if (range == AnalyticsRange.custom) {
      final start = customStart ?? endExclusive.subtract(const Duration(days: 30));
      final end = customEnd ?? now;
      final startUtc = DateTime.utc(start.year, start.month, start.day);
      final endExclUtc = _startOfNextDay(end);
      // Defensive — swap inverted ranges so the rest of the pipeline can
      // assume start < end without re-validating.
      if (!startUtc.isBefore(endExclUtc)) {
        return AnalyticsWindow(
          start: endExclUtc.subtract(const Duration(days: 1)),
          endExclusive: endExclUtc,
        );
      }
      return AnalyticsWindow(start: startUtc, endExclusive: endExclUtc);
    }
    final days = range.days ?? 30;
    final start = endExclusive.subtract(Duration(days: days));
    return AnalyticsWindow(start: start, endExclusive: endExclusive);
  }

  /// Immediately-preceding window of the same length, used to compute the
  /// "vs. previous period" delta chip on every tab.
  AnalyticsWindow previousWindowFor(DateTime now) {
    final cur = windowFor(now);
    final length = cur.endExclusive.difference(cur.start);
    return AnalyticsWindow(
      start: cur.start.subtract(length),
      endExclusive: cur.start,
    );
  }

  /// Bucket granularity for this filter. Presets carry it explicitly;
  /// custom windows auto-pick:
  ///   ≤1 day   → hour
  ///   ≤60 days → day
  ///   else     → month
  BucketGranularity granularityFor(DateTime now) {
    final preset = range.granularity;
    if (preset != null) return preset;
    final w = windowFor(now);
    final days = w.endExclusive.difference(w.start).inDays;
    if (days <= 1) return BucketGranularity.hour;
    if (days <= 60) return BucketGranularity.day;
    return BucketGranularity.month;
  }

  /// How many buckets the time-series charts should paint for this filter.
  /// Preset ranges return their declared count; custom windows derive it
  /// from the resolved granularity.
  int bucketsFor(DateTime now) {
    final preset = range.buckets;
    if (preset != null) return preset;
    final g = granularityFor(now);
    final w = windowFor(now);
    switch (g) {
      case BucketGranularity.hour:
        final hours = w.endExclusive.difference(w.start).inHours;
        return hours <= 0 ? 1 : hours.clamp(1, 48);
      case BucketGranularity.day:
        final days = w.endExclusive.difference(w.start).inDays;
        return days <= 0 ? 1 : days.clamp(1, 365);
      case BucketGranularity.month:
        final days = w.endExclusive.difference(w.start).inDays;
        final months = (days / 30).ceil();
        return months.clamp(2, 24);
    }
  }

  /// Convenience flag — `true` when the active filter buckets by month.
  bool monthlyFor(DateTime now) => granularityFor(now).isMonthly;

  static DateTime _startOfNextDay(DateTime t) {
    final utc = t.toUtc();
    final day = DateTime.utc(utc.year, utc.month, utc.day);
    return day.add(const Duration(days: 1));
  }

  @override
  List<Object?> get props => [range, customStart, customEnd];
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

  Duration get length => endExclusive.difference(start);

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

/// One bucket of order counts (orders tab line chart).
class OrdersPoint extends Equatable {
  const OrdersPoint({required this.bucketStart, required this.count});

  final DateTime bucketStart;
  final int count;

  @override
  List<Object?> get props => [bucketStart, count];
}

/// Best-selling product row used by the "Top mahsulotlar" list.
class TopProduct extends Equatable {
  const TopProduct({
    required this.productId,
    required this.name,
    required this.unitsSold,
    required this.revenue,
    this.imageUrl,
    this.avgRating,
    this.reviewsCount = 0,
  });

  final String productId;
  final String name;
  final int unitsSold;
  final num revenue;
  final String? imageUrl;
  final double? avgRating;
  final int reviewsCount;

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

/// One slice of the orders-by-status donut.
class StatusSlice extends Equatable {
  const StatusSlice({
    required this.status,
    required this.count,
    required this.percent,
  });

  /// Backend status code (see `OrderStatus.code`).
  final String status;
  final int count;
  final double percent;

  @override
  List<Object?> get props => [status, count];
}

/// Aggregated fulfilment metrics for the "Buyurtmalar" tab.
class OrdersBreakdown extends Equatable {
  const OrdersBreakdown({
    required this.total,
    required this.previousTotal,
    required this.byStatus,
    required this.series,
    required this.deliveredCount,
    required this.cancelledCount,
    required this.activeCount,
  });

  /// Orders created inside the window (excludes cancelled — kept separate).
  final int total;
  final int previousTotal;
  final List<StatusSlice> byStatus;
  final List<OrdersPoint> series;

  final int deliveredCount;
  final int cancelledCount;
  final int activeCount;

  factory OrdersBreakdown.empty() => const OrdersBreakdown(
        total: 0,
        previousTotal: 0,
        byStatus: [],
        series: [],
        deliveredCount: 0,
        cancelledCount: 0,
        activeCount: 0,
      );

  /// delivered / (delivered + cancelled). `null` when both are zero (no
  /// completed lifecycle to compute from).
  double? get completionRate {
    final completed = deliveredCount + cancelledCount;
    if (completed == 0) return null;
    return deliveredCount / completed * 100;
  }

  /// cancelled / total. `null` when there are no orders at all.
  double? get cancellationRate {
    if (total == 0) return null;
    return cancelledCount / total * 100;
  }

  double? get deltaPercent {
    if (previousTotal == 0) return null;
    return (total - previousTotal) / previousTotal * 100;
  }

  @override
  List<Object?> get props => [
        total,
        previousTotal,
        byStatus,
        series,
        deliveredCount,
        cancelledCount,
        activeCount,
      ];
}

/// One row in the "recent reviews" preview list. Trimmed down vs. the
/// full [Review] model — analytics never needs the order-item id, only
/// the human-readable summary.
class ReviewPreview extends Equatable {
  const ReviewPreview({
    required this.id,
    required this.rating,
    required this.customerName,
    required this.productName,
    required this.comment,
    required this.createdAt,
    required this.hasReply,
  });

  final String id;
  final int rating;
  final String customerName;
  final String productName;
  final String comment;
  final DateTime createdAt;
  final bool hasReply;

  @override
  List<Object?> get props => [id, rating, hasReply];
}

/// Aggregated customer-voice metrics for the "Baholar" tab.
class ReviewsBreakdown extends Equatable {
  const ReviewsBreakdown({
    required this.total,
    required this.previousTotal,
    required this.average,
    required this.distribution,
    required this.repliedCount,
    required this.series,
    required this.recent,
  });

  final int total;
  final int previousTotal;

  /// Overall average rating in the window, 0..5. `0` when [total] is 0.
  final double average;

  /// Map of star value (1..5) → count. Always carries all five keys
  /// (zero-filled) so the histogram doesn't need null checks.
  final Map<int, int> distribution;

  final int repliedCount;

  /// Reviews-per-day (or per-month) bucket series, same shape as orders.
  final List<OrdersPoint> series;

  /// Latest 5 reviews, newest first, for the inline list.
  final List<ReviewPreview> recent;

  factory ReviewsBreakdown.empty() => const ReviewsBreakdown(
        total: 0,
        previousTotal: 0,
        average: 0,
        distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        repliedCount: 0,
        series: [],
        recent: [],
      );

  double? get replyRate {
    if (total == 0) return null;
    return repliedCount / total * 100;
  }

  double? get deltaPercent {
    if (previousTotal == 0) return null;
    return (total - previousTotal) / previousTotal * 100;
  }

  @override
  List<Object?> get props =>
      [total, previousTotal, average, distribution, repliedCount, series, recent];
}

/// One row in the "top mijozlar" list.
class TopCustomer extends Equatable {
  const TopCustomer({
    required this.customerId,
    required this.name,
    required this.ordersCount,
    required this.totalSpent,
  });

  final String customerId;
  final String name;
  final int ordersCount;
  final num totalSpent;

  @override
  List<Object?> get props => [customerId, totalSpent];
}

/// Aggregated buyer-segmentation metrics for the "Mijozlar" tab.
class CustomersBreakdown extends Equatable {
  const CustomersBreakdown({
    required this.unique,
    required this.previousUnique,
    required this.newCustomers,
    required this.returningCustomers,
    required this.topCustomers,
  });

  /// Distinct customers who placed at least one order in the window.
  final int unique;
  final int previousUnique;

  /// Customers whose first-ever order with this seller falls in the window.
  final int newCustomers;

  /// Customers who had at least one prior order before the window started.
  final int returningCustomers;

  /// Top 5 customers by total spend within the window.
  final List<TopCustomer> topCustomers;

  factory CustomersBreakdown.empty() => const CustomersBreakdown(
        unique: 0,
        previousUnique: 0,
        newCustomers: 0,
        returningCustomers: 0,
        topCustomers: [],
      );

  double? get returningShare {
    if (unique == 0) return null;
    return returningCustomers / unique * 100;
  }

  double? get deltaPercent {
    if (previousUnique == 0) return null;
    return (unique - previousUnique) / previousUnique * 100;
  }

  @override
  List<Object?> get props =>
      [unique, previousUnique, newCustomers, returningCustomers, topCustomers];
}

/// The full analytics snapshot the screen renders. One instance per
/// (filter, fetch); every tab reads from the same snapshot so switching
/// tabs is instant (no refetch).
class AnalyticsSnapshot extends Equatable {
  const AnalyticsSnapshot({
    required this.filter,
    required this.totalRevenue,
    required this.previousRevenue,
    required this.ordersCount,
    required this.unitsSold,
    required this.avgOrderValue,
    required this.series,
    required this.topProducts,
    required this.categoryBreakdown,
    required this.orders,
    required this.reviews,
    required this.customers,
  });

  final AnalyticsFilter filter;

  // ─── Sales tab ─────────────────────────────────────────────────────
  final num totalRevenue;
  final num previousRevenue;
  final int ordersCount;
  final int unitsSold;
  final num avgOrderValue;
  final List<RevenuePoint> series;
  final List<TopProduct> topProducts;
  final List<CategorySlice> categoryBreakdown;

  // ─── Tab-specific rollups ──────────────────────────────────────────
  final OrdersBreakdown orders;
  final ReviewsBreakdown reviews;
  final CustomersBreakdown customers;

  factory AnalyticsSnapshot.empty(AnalyticsFilter filter) => AnalyticsSnapshot(
        filter: filter,
        totalRevenue: 0,
        previousRevenue: 0,
        ordersCount: 0,
        unitsSold: 0,
        avgOrderValue: 0,
        series: const [],
        topProducts: const [],
        categoryBreakdown: const [],
        orders: OrdersBreakdown.empty(),
        reviews: ReviewsBreakdown.empty(),
        customers: CustomersBreakdown.empty(),
      );

  /// Convenience accessor used by the chart title — keeps backwards
  /// compatibility with the previous `snapshot.range` callsites.
  AnalyticsRange get range => filter.range;

  /// Period-over-period delta as a percent. Returns `null` (rather than
  /// `infinity` or `0`) when the previous window's revenue was zero, so
  /// the chip can render "—" instead of a misleading +100% / 0%.
  double? get deltaPercent {
    if (previousRevenue == 0) return null;
    return (totalRevenue - previousRevenue) / previousRevenue * 100;
  }

  bool get isEmpty =>
      totalRevenue == 0 && ordersCount == 0 && reviews.total == 0;

  @override
  List<Object?> get props => [
        filter,
        totalRevenue,
        previousRevenue,
        ordersCount,
        unitsSold,
        avgOrderValue,
        series,
        topProducts,
        categoryBreakdown,
        orders,
        reviews,
        customers,
      ];
}
