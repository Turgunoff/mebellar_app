import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/address.dart';
import '../models/dashboard_snapshot.dart';
import '../models/multilingual_text.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../models/region.dart';
import '../models/shop.dart';
import '../models/tariff.dart';
import 'seller_dashboard_repository.dart';

/// Live Supabase-backed dashboard repo.
///
/// Schema notes:
///   shops    : id, seller_id, name, ...
///   products : id, shop_id, ...
///   orders   : id, user_id, status, total_amount, created_at
///              (no `shop_id` column yet — order→seller is resolved via
///              `order_items.product_id → products.shop_id`)
///
/// Every read is wrapped so a brand-new seller (no shop yet, empty tables,
/// or missing optional tables) reduces to the zero-state snapshot rather
/// than an exception. This is what lets the dashboard render "0" KPIs +
/// the empty-orders illustration on first login.
class SupabaseSellerDashboardRepository implements SellerDashboardRepository {
  SupabaseSellerDashboardRepository(this._client);

  final SupabaseClient _client;

  /// Hardcoded for now — the live `tariffs` table isn't wired into the
  /// dashboard yet. Surfaced as `0 / 30` per the current spec.
  static const int _productLimit = 30;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<DashboardSnapshot> snapshot() async {
    final shopId = await _fetchShopId();

    final results = await Future.wait<num>([
      _safeCountProducts(shopId),
      _safeCountTodaysOrders(shopId),
      _safeSumTodaysRevenue(shopId),
      _safeCountPendingOrders(shopId),
    ]);

    final productsCount = results[0].toInt();
    final todaysOrders = results[1].toInt();
    final todaysRevenue = results[2];
    final pending = results[3].toInt();
    final recentOrders = await _safeRecentOrders(shopId);

    return DashboardSnapshot(
      todaysOrders: todaysOrders,
      todaysRevenue: todaysRevenue,
      pendingOrdersCount: pending,
      activeProductsCount: productsCount,
      tariff: TariffSnapshot(
        plan: TariffPlan.free,
        activeProductsCount: productsCount,
      ),
      recentOrders: recentOrders,
      last30Days: const [],
    );
  }

  /// Resolves the authenticated seller's identity for the greeting:
  ///   - `shopName` from `shops.name` (filter `seller_id = auth.uid()`)
  ///   - `sellerName` from `sellers.legal_name` (PK = `auth.uid()`)
  /// Fired in parallel so the dashboard greeting doesn't pay two RTTs.
  Future<SellerShopInfo> fetchShopInfo() async {
    final userId = _userId;
    if (userId == null) return const SellerShopInfo();

    try {
      final results = await Future.wait<Map<String, dynamic>?>([
        _client
            .from('shops')
            .select('id, name')
            .eq('seller_id', userId)
            .maybeSingle(),
        _client
            .from('sellers')
            .select('legal_name')
            .eq('id', userId)
            .maybeSingle(),
      ]);
      final shopRow = results[0];
      final sellerRow = results[1];

      return SellerShopInfo(
        id: shopRow?['id'] as String?,
        shopName: _trimOrNull(shopRow?['name'] as String?),
        sellerName: _trimOrNull(sellerRow?['legal_name'] as String?),
      );
    } catch (_) {
      return const SellerShopInfo();
    }
  }

  static String? _trimOrNull(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  // Realtime stream is not wired yet — Sprint backend will hook it up. An
  // empty stream keeps the BLoC's `_sub` safe and means the dashboard never
  // sees a fake "new order" event in production.
  @override
  Stream<Order> newOrders() => const Stream.empty();

  // ─── Internals ────────────────────────────────────────────────────────────

  Future<String?> _fetchShopId() async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      final row = await _client
          .from('shops')
          .select('id')
          .eq('seller_id', userId)
          .maybeSingle();
      return row?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<num> _safeCountProducts(String? shopId) async {
    if (shopId == null) return 0;
    try {
      final rows = await _client
          .from('products')
          .select('id')
          .eq('shop_id', shopId);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<num> _safeCountTodaysOrders(String? shopId) async {
    if (shopId == null) return 0;
    try {
      final rows = await _todaysOrderRows(shopId, columns: 'id');
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<num> _safeSumTodaysRevenue(String? shopId) async {
    if (shopId == null) return 0;
    try {
      final rows =
          await _todaysOrderRows(shopId, columns: 'total_amount');
      return rows.fold<num>(
        0,
        (sum, r) => sum + ((r['total_amount'] as num?) ?? 0),
      );
    } catch (_) {
      return 0;
    }
  }

  Future<num> _safeCountPendingOrders(String? shopId) async {
    if (shopId == null) return 0;
    try {
      final orderIds = await _orderIdsForShop(shopId);
      if (orderIds.isEmpty) return 0;
      final rows = await _client
          .from('orders')
          .select('id')
          .inFilter('id', orderIds)
          .eq('status', OrderStatus.pending.code);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Order>> _safeRecentOrders(String? shopId) async {
    if (shopId == null) return const [];
    try {
      final orderIds = await _orderIdsForShop(shopId, limit: 200);
      if (orderIds.isEmpty) return const [];
      final rows = await _client
          .from('orders')
          .select('id, status, total_amount, created_at')
          .inFilter('id', orderIds)
          .order('created_at', ascending: false)
          .limit(5);
      return rows.map<Order>(_minimalOrderFromRow).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns today's order rows belonging to [shopId]. Joins through
  /// `order_items → products` since the live `orders` table doesn't have a
  /// `shop_id` column yet.
  Future<List<Map<String, dynamic>>> _todaysOrderRows(
    String shopId, {
    required String columns,
  }) async {
    final ids = await _orderIdsForShop(shopId);
    if (ids.isEmpty) return const [];
    final startOfDay = DateTime.now().toUtc().copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
    final rows = await _client
        .from('orders')
        .select(columns)
        .inFilter('id', ids)
        .gte('created_at', startOfDay.toIso8601String());
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Walks `order_items` filtered by the seller's products to recover the
  /// distinct order ids that belong to this shop. Capped via [limit] so the
  /// query stays bounded for shops with thousands of historical orders.
  Future<List<String>> _orderIdsForShop(
    String shopId, {
    int limit = 500,
  }) async {
    final productRows = await _client
        .from('products')
        .select('id')
        .eq('shop_id', shopId);
    final productIds = productRows
        .map<String>((r) => r['id'] as String)
        .toList(growable: false);
    if (productIds.isEmpty) return const [];

    final itemRows = await _client
        .from('order_items')
        .select('order_id')
        .inFilter('product_id', productIds)
        .limit(limit);
    final ids = <String>{
      for (final r in itemRows)
        if (r['order_id'] is String) r['order_id'] as String,
    };
    return ids.toList(growable: false);
  }

  Order _minimalOrderFromRow(Map<String, dynamic> row) {
    final id = row['id'] as String;
    return Order(
      id: id,
      orderNumber: 'M-${id.substring(0, 8).toUpperCase()}',
      shop: _placeholderShop,
      items: const [],
      address: _blankAddress,
      deliveryMethod: OrderDeliveryMethod.delivery,
      paymentMethod: OrderPaymentMethod.cashOnDelivery,
      status: OrderStatus.fromCode(row['status'] as String?),
      itemsTotal: 0,
      deliveryFee: 0,
      servicesFee: 0,
      grandTotal: (row['total_amount'] as num?) ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      timeline: const [],
    );
  }

  /// Public so the cubit can surface the limit without hard-coding it.
  static int get productLimit => _productLimit;
}

/// Lightweight value returned by [SupabaseSellerDashboardRepository.fetchShopInfo].
class SellerShopInfo {
  const SellerShopInfo({this.id, this.shopName, this.sellerName});

  final String? id;
  final String? shopName;

  /// `sellers.legal_name`. Trimmed; `null` when blank.
  final String? sellerName;

  bool get hasShop => id != null;
}

// Minimal placeholders so the recent-orders tile can render without the full
// order graph. The dashboard list only reads `orderNumber`, `createdAt`,
// `grandTotal`, and `status`.
const _placeholderShop = Shop(
  id: '_',
  slug: '_',
  name: MultilingualText(uz: "Do'kon", ru: 'Магазин', en: 'Shop'),
);

const _blankRegion = Region(id: '_', code: '_', name: MultilingualText());

const _blankAddress = Address(
  id: '_',
  label: '',
  recipientName: '',
  phone: '',
  region: _blankRegion,
  city: _blankRegion,
  streetLine: '',
);
