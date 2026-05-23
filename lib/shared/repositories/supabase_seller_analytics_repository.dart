import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/logging/talker.dart';
import '../../core/result/result.dart';
import '../models/analytics.dart';
import 'seller_analytics_repository.dart';

/// Supabase-backed analytics. Every metric is computed from the seller's
/// own `orders` / `order_items` / `reviews` rows — RLS already scopes
/// these tables to shop ownership, so the queries below don't carry a
/// per-seller WHERE.
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
  static const String _reviewsTable = 'reviews';
  static const String _shopsTable = 'shops';

  // Embedded select for `order_items` — name, first image, and the
  // category metadata feed the top-products list and donut breakdown.
  static const String _itemEmbed = '''
order_id,
quantity,
price,
product_id,
products!inner(id, name, images, category_id, categories(id, name, name_uz, name_ru))
''';

  // Embedded select for reviews — product name/images + customer profile
  // for the "recent reviews" preview list on the analytics screen.
  static const String _reviewSelect =
      'id, product_id, customer_id, rating, comment, created_at, '
      'seller_reply, seller_replied_at, '
      'products!reviews_product_id_fkey(name, images), '
      'profiles!reviews_customer_id_fkey(full_name)';

  @override
  Future<Result<AnalyticsSnapshot>> snapshot(
    AnalyticsFilter filter, {
    DateTime? now,
  }) =>
      runCatching(() async {
        final clock = now ?? DateTime.now();
        final cur = filter.windowFor(clock);
        final prev = filter.previousWindowFor(clock);

        // Fan out: current orders, previous orders (excluding cancelled),
        // all-status current orders (for the status donut + cancellation
        // rate), and historical orders for new-vs-returning customer
        // detection. RLS narrows every query to the seller's shop.
        final futures = await Future.wait([
          _fetchOrders(
            start: cur.start,
            endExclusive: cur.endExclusive,
            excludeCancelled: true,
          ),
          _fetchOrders(
            start: prev.start,
            endExclusive: prev.endExclusive,
            excludeCancelled: true,
          ),
          _fetchOrdersAllStatuses(
            start: cur.start,
            endExclusive: cur.endExclusive,
          ),
          _fetchCustomerIdsBefore(cur.start),
          _fetchPreviousReviewCount(start: prev.start, endExclusive: prev.endExclusive),
        ]);
        final currentOrders = futures[0] as List<Map<String, dynamic>>;
        final previousOrders = futures[1] as List<Map<String, dynamic>>;
        final allStatusCurrent = futures[2] as List<Map<String, dynamic>>;
        final priorCustomerIds = futures[3] as Set<String>;
        final previousReviewsCount = futures[4] as int;

        final shopId = await _resolveShopId();

        // Items: one round-trip for every line item across both windows.
        // The `products!inner(...)` join enforces seller ownership at the
        // join (and RLS doubles it up) — items from other sellers'
        // products in the same multi-vendor order do not come back.
        final currentOrderIds = _idsOf(currentOrders);
        final previousOrderIds = _idsOf(previousOrders);
        final allItemOrderIds = {...currentOrderIds, ...previousOrderIds};
        final itemRows = allItemOrderIds.isEmpty
            ? const <Map<String, dynamic>>[]
            : await _fetchItems(allItemOrderIds);

        // Reviews — within the current window for the headline stats,
        // plus the 5 latest overall for the "recent" list. Both queries
        // are shop-scoped via the indexed `shop_id` column.
        final reviewsRows = shopId == null
            ? const <Map<String, dynamic>>[]
            : await _fetchReviews(
                shopId: shopId,
                start: cur.start,
                endExclusive: cur.endExclusive,
              );
        final recentReviewsRows = shopId == null
            ? const <Map<String, dynamic>>[]
            : await _fetchRecentReviews(shopId: shopId, limit: 5);

        if (allItemOrderIds.isEmpty &&
            allStatusCurrent.isEmpty &&
            reviewsRows.isEmpty &&
            recentReviewsRows.isEmpty) {
          return AnalyticsSnapshot.empty(filter);
        }

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

        final granularity = filter.granularityFor(clock);
        final bucketCount = filter.bucketsFor(clock);

        return AnalyticsSnapshot(
          filter: filter,
          totalRevenue: currentRevenue,
          previousRevenue: previousRevenue,
          ordersCount: ordersCount,
          unitsSold: unitsSold,
          avgOrderValue: avgOrderValue,
          series: _buildRevenueSeries(
            window: cur,
            bucketCount: bucketCount,
            granularity: granularity,
            orders: currentOrders,
            itemsByOrder: _groupItemsByOrder(currentItems),
          ),
          topProducts: _topProducts(currentItems),
          categoryBreakdown: _categoryBreakdown(
            currentItems,
            totalRevenue: currentRevenue,
          ),
          orders: _buildOrdersBreakdown(
            currentAll: allStatusCurrent,
            currentNonCancelled: currentOrders,
            previousNonCancelled: previousOrders,
            window: cur,
            bucketCount: bucketCount,
            granularity: granularity,
          ),
          reviews: _buildReviewsBreakdown(
            currentReviews: reviewsRows,
            previousCount: previousReviewsCount,
            recent: recentReviewsRows,
            window: cur,
            bucketCount: bucketCount,
            granularity: granularity,
          ),
          customers: _buildCustomersBreakdown(
            currentOrders: currentOrders,
            previousOrders: previousOrders,
            priorCustomerIds: priorCustomerIds,
            itemsByOrder: _groupItemsByOrder(currentItems),
          ),
        );
      }, onError: (e, st) {
        talker.handle(e, st, 'SupabaseSellerAnalytics.snapshot');
        return ServerFailure(
          message: "Analitika ma'lumotlarini yuklab bo'lmadi: $e",
        );
      });

  // ─── Network helpers ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchOrders({
    required DateTime start,
    required DateTime endExclusive,
    required bool excludeCancelled,
  }) async {
    final builder = _client
        .from(_ordersTable)
        .select('id, user_id, created_at, status, total_amount')
        .gte('created_at', start.toIso8601String())
        .lt('created_at', endExclusive.toIso8601String());
    final rows = excludeCancelled
        ? await builder.neq('status', 'cancelled')
        : await builder;
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> _fetchOrdersAllStatuses({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final rows = await _client
        .from(_ordersTable)
        .select('id, user_id, created_at, status, total_amount')
        .gte('created_at', start.toIso8601String())
        .lt('created_at', endExclusive.toIso8601String());
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> _fetchItems(Set<String> orderIds) async {
    final rows = await _client
        .from(_itemsTable)
        .select(_itemEmbed)
        .inFilter('order_id', orderIds.toList(growable: false));
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Customers who placed at least one order before [before]. Used to
  /// classify orders inside the window as new vs. returning — a customer
  /// is "returning" iff their id appears in this set.
  Future<Set<String>> _fetchCustomerIdsBefore(DateTime before) async {
    final rows = await _client
        .from(_ordersTable)
        .select('user_id')
        .lt('created_at', before.toIso8601String());
    return {
      for (final r in rows)
        if (r['user_id'] is String) r['user_id'] as String,
    };
  }

  Future<List<Map<String, dynamic>>> _fetchReviews({
    required String shopId,
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final rows = await _client
        .from(_reviewsTable)
        .select(_reviewSelect)
        .eq('shop_id', shopId)
        .gte('created_at', start.toIso8601String())
        .lt('created_at', endExclusive.toIso8601String());
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<int> _fetchPreviousReviewCount({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final shopId = await _resolveShopId();
    if (shopId == null) return 0;
    final rows = await _client
        .from(_reviewsTable)
        .select('id')
        .eq('shop_id', shopId)
        .gte('created_at', start.toIso8601String())
        .lt('created_at', endExclusive.toIso8601String());
    return (rows as List).length;
  }

  Future<List<Map<String, dynamic>>> _fetchRecentReviews({
    required String shopId,
    required int limit,
  }) async {
    final rows = await _client
        .from(_reviewsTable)
        .select(_reviewSelect)
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Resolves the active seller's shop id. Memoised per cubit lifecycle
  /// would be nicer, but a single round-trip per refresh is cheap enough
  /// to skip the cache layer.
  String? _shopIdCache;
  Future<String?> _resolveShopId() async {
    if (_shopIdCache != null) return _shopIdCache;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from(_shopsTable)
        .select('id')
        .eq('seller_id', userId)
        .maybeSingle();
    _shopIdCache = row?['id'] as String?;
    return _shopIdCache;
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

  /// Builds bucketed [RevenuePoint]s for any granularity (hour/day/month).
  /// Each bucket sums the revenue of orders whose `created_at` falls into
  /// it.
  static List<RevenuePoint> _buildRevenueSeries({
    required AnalyticsWindow window,
    required int bucketCount,
    required BucketGranularity granularity,
    required List<Map<String, dynamic>> orders,
    required Map<String, List<Map<String, dynamic>>> itemsByOrder,
  }) {
    final points = _initBuckets(
      window: window,
      bucketCount: bucketCount,
      granularity: granularity,
    );
    for (final order in orders) {
      final created = _parseUtc(order['created_at']);
      if (created == null || !window.contains(created)) continue;
      final key = _bucketKey(created: created, granularity: granularity);
      final orderId = order['id'] as String?;
      if (orderId == null) continue;
      final items = itemsByOrder[orderId] ?? const [];
      final revenue = _sumRevenue(items);
      // Snap to the nearest available bucket — guards against bucket
      // keys that don't line up exactly with the order's `created_at`.
      final snap = _snapToBucket(points.keys, key);
      if (snap != null) {
        points[snap] = (points[snap] ?? 0) + revenue;
      }
    }
    final keys = points.keys.toList()..sort();
    return [
      for (final k in keys) RevenuePoint(bucketStart: k, revenue: points[k] ?? 0),
    ];
  }

  static List<OrdersPoint> _buildOrdersSeries({
    required AnalyticsWindow window,
    required int bucketCount,
    required BucketGranularity granularity,
    required List<Map<String, dynamic>> orders,
  }) {
    final points = _initBuckets(
      window: window,
      bucketCount: bucketCount,
      granularity: granularity,
    );
    for (final order in orders) {
      final created = _parseUtc(order['created_at']);
      if (created == null || !window.contains(created)) continue;
      final key = _bucketKey(created: created, granularity: granularity);
      final snap = _snapToBucket(points.keys, key);
      if (snap != null) {
        points[snap] = (points[snap] ?? 0) + 1;
      }
    }
    final keys = points.keys.toList()..sort();
    return [
      for (final k in keys)
        OrdersPoint(bucketStart: k, count: (points[k] ?? 0).toInt()),
    ];
  }

  static Map<DateTime, num> _initBuckets({
    required AnalyticsWindow window,
    required int bucketCount,
    required BucketGranularity granularity,
  }) {
    final map = <DateTime, num>{};
    switch (granularity) {
      case BucketGranularity.hour:
        // One bucket per hour starting at the window start; we walk forward
        // so the chart x-axis reads oldest → newest left → right.
        for (var i = 0; i < bucketCount; i++) {
          final hour = window.start.add(Duration(hours: i));
          map[hour] = 0;
        }
      case BucketGranularity.month:
        // Month buckets walk from oldest → newest. The exclusive end sits
        // one past the latest visible month, so subtract by index.
        final endMonth = DateTime.utc(
          window.endExclusive.year,
          window.endExclusive.month,
        );
        for (var i = 0; i < bucketCount; i++) {
          final monthsBack = bucketCount - 1 - i;
          final key =
              DateTime.utc(endMonth.year, endMonth.month - monthsBack - 1);
          map[key] = 0;
        }
      case BucketGranularity.day:
        // Day buckets — one per day, starting from the window start.
        for (var i = 0; i < bucketCount; i++) {
          final day = window.start.add(Duration(days: i));
          map[day] = 0;
        }
    }
    return map;
  }

  static DateTime _bucketKey({
    required DateTime created,
    required BucketGranularity granularity,
  }) {
    final utc = created.toUtc();
    return switch (granularity) {
      BucketGranularity.hour =>
        DateTime.utc(utc.year, utc.month, utc.day, utc.hour),
      BucketGranularity.day => DateTime.utc(utc.year, utc.month, utc.day),
      BucketGranularity.month => DateTime.utc(utc.year, utc.month),
    };
  }

  /// Maps an arbitrary bucket key to the nearest pre-initialised key.
  /// Day-keyed series usually match exactly; month series and short
  /// windows can drift by a day, so we round to the nearest <= key.
  static DateTime? _snapToBucket(Iterable<DateTime> keys, DateTime key) {
    if (keys.isEmpty) return null;
    DateTime? best;
    for (final k in keys) {
      if (!k.isAfter(key)) {
        if (best == null || k.isAfter(best)) best = k;
      }
    }
    // Fall back to the first key when nothing precedes (window edge case).
    if (best == null) {
      final sorted = keys.toList()..sort();
      return sorted.first;
    }
    return best;
  }

  static DateTime? _parseUtc(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
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

  static OrdersBreakdown _buildOrdersBreakdown({
    required List<Map<String, dynamic>> currentAll,
    required List<Map<String, dynamic>> currentNonCancelled,
    required List<Map<String, dynamic>> previousNonCancelled,
    required AnalyticsWindow window,
    required int bucketCount,
    required BucketGranularity granularity,
  }) {
    if (currentAll.isEmpty) {
      return OrdersBreakdown.empty().._withSeries(
        _buildOrdersSeries(
          window: window,
          bucketCount: bucketCount,
          granularity: granularity,
          orders: const [],
        ),
      );
    }

    final statusCounts = <String, int>{};
    var delivered = 0;
    var cancelled = 0;
    for (final row in currentAll) {
      final status = (row['status'] as String?) ?? 'pending';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      if (status == 'delivered') delivered++;
      if (status == 'cancelled') cancelled++;
    }
    final totalAll = currentAll.length;
    final active = totalAll - delivered - cancelled;

    final slices = <StatusSlice>[];
    statusCounts.forEach((status, count) {
      slices.add(StatusSlice(
        status: status,
        count: count,
        percent: totalAll == 0 ? 0 : count / totalAll * 100,
      ));
    });
    slices.sort((a, b) => b.count.compareTo(a.count));

    return OrdersBreakdown(
      total: totalAll,
      // Count cancelled in the previous window too so the period-over-period
      // delta reflects raw order volume, not just successful sales.
      previousTotal: previousNonCancelled.length,
      byStatus: slices,
      series: _buildOrdersSeries(
        window: window,
        bucketCount: bucketCount,
        granularity: granularity,
        orders: currentAll,
      ),
      deliveredCount: delivered,
      cancelledCount: cancelled,
      activeCount: active < 0 ? 0 : active,
    );
  }

  static ReviewsBreakdown _buildReviewsBreakdown({
    required List<Map<String, dynamic>> currentReviews,
    required int previousCount,
    required List<Map<String, dynamic>> recent,
    required AnalyticsWindow window,
    required int bucketCount,
    required BucketGranularity granularity,
  }) {
    final dist = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    var sum = 0;
    var replied = 0;
    for (final row in currentReviews) {
      final rating = ((row['rating'] as num?) ?? 0).toInt().clamp(1, 5);
      dist[rating] = (dist[rating] ?? 0) + 1;
      sum += rating;
      final reply = row['seller_reply'];
      if (reply is String && reply.trim().isNotEmpty) replied++;
    }
    final total = currentReviews.length;
    final avg = total == 0 ? 0.0 : sum / total;

    // Map current reviews to an OrdersPoint series for the line chart.
    final timeMap = _initBuckets(
      window: window,
      bucketCount: bucketCount,
      granularity: granularity,
    );
    for (final row in currentReviews) {
      final created = _parseUtc(row['created_at']);
      if (created == null || !window.contains(created)) continue;
      final key = _bucketKey(created: created, granularity: granularity);
      final snap = _snapToBucket(timeMap.keys, key);
      if (snap != null) timeMap[snap] = (timeMap[snap] ?? 0) + 1;
    }
    final keys = timeMap.keys.toList()..sort();
    final series = [
      for (final k in keys)
        OrdersPoint(bucketStart: k, count: (timeMap[k] ?? 0).toInt()),
    ];

    return ReviewsBreakdown(
      total: total,
      previousTotal: previousCount,
      average: avg,
      distribution: dist,
      repliedCount: replied,
      series: series,
      recent: recent.map(_toReviewPreview).toList(growable: false),
    );
  }

  static ReviewPreview _toReviewPreview(Map<String, dynamic> row) {
    final product = row['products'];
    String productName = 'Mahsulot';
    if (product is Map<String, dynamic>) {
      final raw = product['name'];
      if (raw is Map) {
        for (final key in const ['uz', 'ru', 'en']) {
          final v = raw[key];
          if (v is String && v.trim().isNotEmpty) {
            productName = v.trim();
            break;
          }
        }
      } else if (raw is String && raw.trim().isNotEmpty) {
        productName = raw.trim();
      }
    }
    final profile = row['profiles'];
    String customerName = 'Xaridor';
    if (profile is Map<String, dynamic>) {
      final n = profile['full_name'];
      if (n is String && n.trim().isNotEmpty) customerName = n.trim();
    }
    final reply = row['seller_reply'];
    return ReviewPreview(
      id: row['id'] as String? ?? '',
      rating: ((row['rating'] as num?) ?? 0).toInt(),
      customerName: customerName,
      productName: productName,
      comment: (row['comment'] as String?) ?? '',
      createdAt: _parseUtc(row['created_at']) ?? DateTime.now().toUtc(),
      hasReply: reply is String && reply.trim().isNotEmpty,
    );
  }

  static CustomersBreakdown _buildCustomersBreakdown({
    required List<Map<String, dynamic>> currentOrders,
    required List<Map<String, dynamic>> previousOrders,
    required Set<String> priorCustomerIds,
    required Map<String, List<Map<String, dynamic>>> itemsByOrder,
  }) {
    if (currentOrders.isEmpty) return CustomersBreakdown.empty();

    final spendByCustomer = <String, num>{};
    final ordersByCustomer = <String, int>{};
    final currentCustomerIds = <String>{};
    for (final order in currentOrders) {
      final uid = order['user_id'] as String?;
      if (uid == null) continue;
      currentCustomerIds.add(uid);
      final orderId = order['id'] as String?;
      final revenue =
          orderId == null ? 0 : _sumRevenue(itemsByOrder[orderId] ?? const []);
      spendByCustomer[uid] = (spendByCustomer[uid] ?? 0) + revenue;
      ordersByCustomer[uid] = (ordersByCustomer[uid] ?? 0) + 1;
    }

    final previousCustomerIds = <String>{
      for (final o in previousOrders)
        if (o['user_id'] is String) o['user_id'] as String,
    };

    var returning = 0;
    for (final id in currentCustomerIds) {
      if (priorCustomerIds.contains(id)) returning++;
    }
    final newCount = currentCustomerIds.length - returning;

    final topList = spendByCustomer.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = topList.take(5).map((e) {
      return TopCustomer(
        customerId: e.key,
        name: 'Mijoz ${e.key.substring(0, e.key.length.clamp(0, 6))}',
        ordersCount: ordersByCustomer[e.key] ?? 0,
        totalSpent: e.value,
      );
    }).toList(growable: false);

    return CustomersBreakdown(
      unique: currentCustomerIds.length,
      previousUnique: previousCustomerIds.length,
      newCustomers: newCount < 0 ? 0 : newCount,
      returningCustomers: returning,
      topCustomers: top,
    );
  }
}

extension on OrdersBreakdown {
  // Tiny helper used only in the empty-fallback path so the empty
  // breakdown still carries a fully zero-filled time series.
  OrdersBreakdown _withSeries(List<OrdersPoint> s) {
    return OrdersBreakdown(
      total: total,
      previousTotal: previousTotal,
      byStatus: byStatus,
      series: s,
      deliveredCount: deliveredCount,
      cancelledCount: cancelledCount,
      activeCount: activeCount,
    );
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
