import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/logging/talker.dart';
import '../../core/result/result.dart';
import '../models/analytics.dart';
import 'seller_analytics_repository.dart';

/// Supabase-backed analytics. Every metric is computed from the seller's
/// own `orders` / `order_items` rows — RLS already scopes both tables to
/// shop ownership, so the queries below don't carry a per-seller WHERE.
///
/// Aggregation lives in Dart on purpose: PostgREST has no GROUP BY for
/// the buckets we render (per-day revenue, per-category share), and the
/// cardinality is tiny — a seller's analytics surface tops out at a few
/// thousand line items in the longest window. A future scale problem
/// would shift this into a Postgres view or RPC; until then, a single
/// dependency-free `runCatching` block keeps the logic readable.
class SupabaseSellerAnalyticsRepository implements SellerAnalyticsRepository {
  SupabaseSellerAnalyticsRepository({required SupabaseClient supabase})
      : _client = supabase;

  final SupabaseClient _client;

  static const String _ordersTable = 'orders';
  static const String _itemsTable = 'order_items';

  // Embedded select for `order_items` — name, first image, and the
  // category metadata feed the top-products list and donut breakdown.
  static const String _itemEmbed = '''
order_id,
quantity,
price,
product_id,
products!inner(id, name, images, category_id, categories(id, name, name_uz, name_ru))
''';

  @override
  Future<Result<AnalyticsSnapshot>> snapshot(
    AnalyticsRange range, {
    DateTime? now,
  }) =>
      runCatching(() async {
        final clock = now ?? DateTime.now();
        final cur = range.currentWindow(clock);
        final prev = range.previousWindow(clock);

        // Two parallel order-row fetches. RLS narrows both to orders the
        // seller can see; cancelled orders are excluded so refunded / void
        // revenue doesn't poison the trend chip.
        final results = await Future.wait<List<Map<String, dynamic>>>([
          _fetchOrders(start: cur.start, endExclusive: cur.endExclusive),
          _fetchOrders(start: prev.start, endExclusive: prev.endExclusive),
        ]);
        final currentOrders = results[0];
        final previousOrders = results[1];

        final currentOrderIds = _idsOf(currentOrders);
        final previousOrderIds = _idsOf(previousOrders);
        final allOrderIds = {...currentOrderIds, ...previousOrderIds};
        if (allOrderIds.isEmpty) {
          return AnalyticsSnapshot.empty(range);
        }

        // One round-trip for every line item across both windows. The
        // `products!inner(...)` join enforces seller ownership at the
        // join (and RLS doubles it up) — items from other sellers'
        // products in the same multi-vendor order do not come back.
        final itemRows = await _client
            .from(_itemsTable)
            .select(_itemEmbed)
            .inFilter('order_id', allOrderIds.toList(growable: false));

        // Partition items by which window's order they belong to.
        final currentItems = <Map<String, dynamic>>[];
        final previousItems = <Map<String, dynamic>>[];
        for (final row in itemRows) {
          final orderId = row['order_id'] as String?;
          if (orderId == null) continue;
          if (currentOrderIds.contains(orderId)) {
            currentItems.add(row);
          } else if (previousOrderIds.contains(orderId)) {
            previousItems.add(row);
          }
        }

        final currentRevenue = _sumRevenue(currentItems);
        final previousRevenue = _sumRevenue(previousItems);
        final unitsSold = _sumQuantity(currentItems);
        final ordersCount = currentOrders.length;
        final avgOrderValue =
            ordersCount == 0 ? 0 : currentRevenue / ordersCount;

        return AnalyticsSnapshot(
          range: range,
          totalRevenue: currentRevenue,
          previousRevenue: previousRevenue,
          ordersCount: ordersCount,
          unitsSold: unitsSold,
          avgOrderValue: avgOrderValue,
          series: _buildSeries(
            range: range,
            window: cur,
            orders: currentOrders,
            itemsByOrder: _groupItemsByOrder(currentItems),
          ),
          topProducts: _topProducts(currentItems),
          categoryBreakdown: _categoryBreakdown(
            currentItems,
            totalRevenue: currentRevenue,
          ),
        );
      }, onError: (e, st) {
        // Pass through `Failure` types untouched; map other exceptions
        // (PostgrestException etc.) to a UI-friendly message and log the
        // full stack to Sentry/Talker for follow-up.
        talker.handle(e, st, 'SupabaseSellerAnalytics.snapshot');
        return ServerFailure(
          message: "Analitika ma'lumotlarini yuklab bo'lmadi: $e",
        );
      });

  // ─── Network helpers ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchOrders({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final rows = await _client
        .from(_ordersTable)
        .select('id, created_at, status, total_amount')
        .neq('status', 'cancelled')
        .gte('created_at', start.toIso8601String())
        .lt('created_at', endExclusive.toIso8601String());
    return List<Map<String, dynamic>>.from(rows);
  }

  // ─── Aggregation helpers ─────────────────────────────────────────────

  static Set<String> _idsOf(List<Map<String, dynamic>> rows) => {
        for (final r in rows)
          if (r['id'] is String) r['id'] as String,
      };

  static num _sumRevenue(List<Map<String, dynamic>> items) {
    var total = num.parse('0');
    for (final r in items) {
      final qty = (r['quantity'] as num?) ?? 0;
      final price = (r['price'] as num?) ?? 0;
      total += qty * price;
    }
    return total;
  }

  static int _sumQuantity(List<Map<String, dynamic>> items) {
    var total = 0;
    for (final r in items) {
      total += ((r['quantity'] as num?) ?? 0).toInt();
    }
    return total;
  }

  static Map<String, List<Map<String, dynamic>>> _groupItemsByOrder(
    List<Map<String, dynamic>> items,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final row in items) {
      final orderId = row['order_id'] as String?;
      if (orderId == null) continue;
      map.putIfAbsent(orderId, () => <Map<String, dynamic>>[]).add(row);
    }
    return map;
  }

  /// Builds bucketed [RevenuePoint]s. Day-grained for 7d/30d, month-grained
  /// for 12mo. Each bucket sums the revenue of orders whose `created_at`
  /// falls into it; orders with no seller-owned items contribute 0 (they
  /// were excluded by the items query, so their bucket stays empty).
  static List<RevenuePoint> _buildSeries({
    required AnalyticsRange range,
    required AnalyticsWindow window,
    required List<Map<String, dynamic>> orders,
    required Map<String, List<Map<String, dynamic>>> itemsByOrder,
  }) {
    final points = <DateTime, num>{};
    for (var i = 0; i < range.buckets; i++) {
      final bucketStart =
          _bucketStartAt(window: window, range: range, index: i);
      points[bucketStart] = 0;
    }

    for (final order in orders) {
      final createdRaw = order['created_at'] as String?;
      if (createdRaw == null) continue;
      final created = DateTime.tryParse(createdRaw)?.toUtc();
      if (created == null || !window.contains(created)) continue;
      final bucketStart =
          _bucketStartFor(timestamp: created, window: window, range: range);
      final orderId = order['id'] as String?;
      if (orderId == null) continue;
      final items = itemsByOrder[orderId] ?? const [];
      final revenue = _sumRevenue(items);
      points[bucketStart] = (points[bucketStart] ?? 0) + revenue;
    }

    final keys = points.keys.toList()..sort();
    return [
      for (final k in keys)
        RevenuePoint(bucketStart: k, revenue: points[k] ?? 0),
    ];
  }

  /// Start (UTC) of the [index]-th bucket inside [window]. Day-grained for
  /// 7d/30d; month-grained for 12mo (last 12 months counting from the
  /// month containing the window's end-of-day).
  static DateTime _bucketStartAt({
    required AnalyticsWindow window,
    required AnalyticsRange range,
    required int index,
  }) {
    if (range.isMonthly) {
      final endMonth = DateTime.utc(
        window.endExclusive.year,
        window.endExclusive.month - 1,
      );
      // The endExclusive month sits one past the last visible bucket;
      // subtract by month index counting from oldest → newest.
      final monthsBack = range.buckets - 1 - index;
      return DateTime.utc(endMonth.year, endMonth.month - monthsBack);
    }
    return window.start.add(Duration(days: index));
  }

  /// Inverse of [_bucketStartAt]: maps a concrete order timestamp to the
  /// bucket key it falls under.
  static DateTime _bucketStartFor({
    required DateTime timestamp,
    required AnalyticsWindow window,
    required AnalyticsRange range,
  }) {
    if (range.isMonthly) {
      return DateTime.utc(timestamp.year, timestamp.month);
    }
    return DateTime.utc(timestamp.year, timestamp.month, timestamp.day);
  }

  static List<TopProduct> _topProducts(List<Map<String, dynamic>> items) {
    final acc = <String, _ProductAccumulator>{};
    for (final row in items) {
      final productId = row['product_id'] as String?;
      if (productId == null) continue;
      final product = row['products'];
      String name = '';
      String? image;
      if (product is Map<String, dynamic>) {
        name = product['name'] as String? ?? '';
        final images = product['images'];
        if (images is List && images.isNotEmpty) {
          image = images.first?.toString();
        }
      }
      final qty = ((row['quantity'] as num?) ?? 0).toInt();
      final revenue = ((row['quantity'] as num?) ?? 0) *
          ((row['price'] as num?) ?? 0);
      final accumulator = acc.putIfAbsent(
        productId,
        () => _ProductAccumulator(productId: productId, name: name, image: image),
      );
      accumulator.units += qty;
      accumulator.revenue += revenue;
    }

    final list = acc.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return list
        .take(5)
        .map((a) => TopProduct(
              productId: a.productId,
              name: a.name.isEmpty ? 'Mahsulot' : a.name,
              unitsSold: a.units,
              revenue: a.revenue,
              imageUrl: a.image,
            ))
        .toList(growable: false);
  }

  static List<CategorySlice> _categoryBreakdown(
    List<Map<String, dynamic>> items, {
    required num totalRevenue,
  }) {
    if (items.isEmpty || totalRevenue <= 0) return const [];

    final acc = <String?, _CategoryAccumulator>{};
    for (final row in items) {
      final product = row['products'];
      String? categoryId;
      String label = 'Boshqa';
      if (product is Map<String, dynamic>) {
        categoryId = product['category_id'] as String?;
        final category = product['categories'];
        if (category is Map<String, dynamic>) {
          // Prefer the localised name_uz, then name, then name_ru.
          label = (category['name_uz'] as String?)?.trim().isNotEmpty == true
              ? category['name_uz'] as String
              : (category['name'] as String?)?.trim().isNotEmpty == true
                  ? category['name'] as String
                  : (category['name_ru'] as String?)?.trim().isNotEmpty == true
                      ? category['name_ru'] as String
                      : 'Boshqa';
        }
      }
      final revenue = ((row['quantity'] as num?) ?? 0) *
          ((row['price'] as num?) ?? 0);
      final entry = acc.putIfAbsent(
        categoryId,
        () => _CategoryAccumulator(id: categoryId, label: label),
      );
      entry.revenue += revenue;
    }

    final list = acc.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return [
      for (final c in list)
        CategorySlice(
          categoryId: c.id,
          label: c.label,
          revenue: c.revenue,
          percent: (c.revenue / totalRevenue * 100).clamp(0, 100).toDouble(),
        ),
    ];
  }
}

class _ProductAccumulator {
  _ProductAccumulator({
    required this.productId,
    required this.name,
    this.image,
  });
  final String productId;
  final String name;
  final String? image;
  int units = 0;
  num revenue = 0;
}

class _CategoryAccumulator {
  _CategoryAccumulator({required this.id, required this.label});
  final String? id;
  final String label;
  num revenue = 0;
}
