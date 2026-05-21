import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/logging/talker.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/result/result.dart';
import '../models/address.dart';
import '../models/multilingual_text.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../models/region.dart';
import 'seller_order_repository.dart';

/// Live Supabase implementation of [SellerOrderRepository] (ROADMAP B.1).
///
/// Schema — verified against the live database:
/// ```
///   orders      id · user_id · status · total_amount · created_at ·
///               delivery_address · cancellation_reason
///   order_items id · order_id · product_id · quantity · price
///   products    id · shop_id · seller_id
/// ```
/// `orders` has no `shop_id`; an order belongs to a seller transitively via
/// `order_items → products → shops.seller_id`. Realtime therefore subscribes
/// to *all* pending-order inserts and post-filters by shop ownership.
class SupabaseSellerOrderRepository implements SellerOrderRepository {
  SupabaseSellerOrderRepository({
    required SupabaseClient supabase,
    required RealtimeService realtime,
  })  : _client = supabase,
        _realtime = realtime {
    // ROADMAP B.7 realtime audit — this repo is root-scoped, so the orders
    // channel must NOT simply live until app exit: bind it to listener
    // presence. The channel opens when the orders bloc starts listening and
    // closes when it stops (e.g. a customer<->seller mode switch tears the
    // bloc down) — no websocket leak across mode switches.
    _newOrders = StreamController<Order>.broadcast(
      onListen: () => unawaited(_ensureNewOrdersSubscription()),
      onCancel: () => unawaited(_teardownNewOrdersSubscription()),
    );
  }

  final SupabaseClient _client;
  final RealtimeService _realtime;

  static const String _ordersTable = 'orders';
  static const String _itemsTable = 'order_items';

  late final StreamController<Order> _newOrders;
  RealtimeSubscription? _newOrdersSub;
  RealtimeSubscription? _updatesSub;
  bool _subscribing = false;
  bool _updatesSubscribing = false;
  bool _disposed = false;
  int _watchSeq = 0;

  /// Broadcast feed of UPDATEs on any order the seller can read. The orders
  /// list bloc listens here so a customer-side cancel (or another tab's
  /// status change) flows back without a manual refresh. Realtime delivery
  /// is RLS-gated by the seller policy on `orders`, so we still confirm
  /// shop ownership before forwarding — Postgres' RLS bridging on logical
  /// replication isn't 100% guaranteed across all releases.
  late final StreamController<Order> _orderUpdates =
      StreamController<Order>.broadcast(
    onListen: () => unawaited(_ensureUpdatesSubscription()),
    onCancel: () => unawaited(_teardownUpdatesSubscription()),
  );

  // Embedded select used by both list() and _fetchOrder so the line-items
  // come back with the product name + first image already joined — sellers'
  // line rows otherwise carry only ids, leaving the UI to render empty
  // labels. `inner` keeps order_items whose product was filtered out by
  // RLS off the result altogether.
  static const String _itemEmbed =
      'id, order_id, product_id, quantity, price, '
      'products!inner(id, name, images)';

  @override
  Future<Result<List<Order>>> list() => runCatching(() async {
        final shopId = await _requireShopId();
        final orderIds = await _orderIdsForShop(shopId);
        if (orderIds.isEmpty) return <Order>[];
        final rows = await _client
            .from(_ordersTable)
            .select()
            .inFilter('id', orderIds)
            .order('created_at', ascending: false);
        if (rows.isEmpty) return <Order>[];
        // Fetch the joined item rows in one round-trip and bucket them by
        // order_id so each `Order.fromJson` lands with its enriched lines.
        // Per the RLS policy, sellers only see line items whose product is
        // theirs — line counts in this map are scoped to the seller.
        final itemsByOrder = await _fetchItemsByOrderId(rows
            .map((r) => r['id'] as String)
            .toList(growable: false));
        return rows
            .map(
              (row) => Order.fromJson(
                row,
                items: itemsByOrder[row['id'] as String] ?? const [],
              ),
            )
            .toList(growable: false);
      });

  @override
  Future<Result<Order>> getById(String id) =>
      runCatching(() => _fetchOrder(id));

  /// Shared loader — the order row plus its `order_items` and the buyer's
  /// contact info (name + phone from `profiles`). Throws a [Failure] (caught
  /// by [runCatching]) when the row is missing.
  Future<Order> _fetchOrder(String id) async {
    final row =
        await _client.from(_ordersTable).select().eq('id', id).maybeSingle();
    if (row == null) {
      throw const ServerFailure(message: 'Buyurtma topilmadi');
    }
    final itemsByOrder = await _fetchItemsByOrderId([id]);
    final address = await _fetchBuyerContact(
      row['user_id'] as String?,
      row['delivery_address'] as String?,
    );
    return Order.fromJson(
      row,
      items: itemsByOrder[id] ?? const [],
      address: address,
    );
  }

  /// Fetches buyer name + phone from `profiles` for the seller's contact card.
  /// Returns `null` on failure so the detail screen degrades gracefully.
  Future<Address?> _fetchBuyerContact(
    String? userId,
    String? deliveryAddressText,
  ) async {
    if (userId == null) return null;
    try {
      final profile = await _client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null) return null;
      return Address(
        id: userId,
        label: '',
        recipientName: profile['full_name'] as String? ?? '',
        phone: profile['phone'] as String? ?? '',
        region: const Region(id: '_', code: '_', name: MultilingualText()),
        city: const Region(id: '_', code: '_', name: MultilingualText()),
        streetLine: deliveryAddressText ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// One-shot fetch of every visible line item across [orderIds], joined
  /// with `products` for the name + first image. Returned as a
  /// `{ order_id -> items }` map so the caller can stitch the lines onto
  /// the parent Order without a per-order round-trip.
  Future<Map<String, List<OrderItem>>> _fetchItemsByOrderId(
    List<String> orderIds,
  ) async {
    if (orderIds.isEmpty) return const {};
    final rows = await _client
        .from(_itemsTable)
        .select(_itemEmbed)
        .inFilter('order_id', orderIds);
    final result = <String, List<OrderItem>>{};
    for (final row in rows) {
      final orderId = row['order_id'] as String?;
      if (orderId == null) continue;
      result
          .putIfAbsent(orderId, () => <OrderItem>[])
          .add(_orderItemFromJoinedRow(row));
    }
    return result;
  }

  /// Adapts a joined `order_items + products` row into an [OrderItem]. The
  /// `products!inner(...)` embed lands on the row under the `products`
  /// key as a single object; we lift `name` and the first image so the
  /// seller-side list/detail screens render something readable instead of
  /// blank tiles.
  static OrderItem _orderItemFromJoinedRow(Map<String, dynamic> row) {
    final product = row['products'];
    final name = product is Map<String, dynamic>
        ? product['name'] as String? ?? ''
        : '';
    final images = product is Map<String, dynamic> ? product['images'] : null;
    final firstImage = images is List && images.isNotEmpty
        ? images.first?.toString() ?? ''
        : '';
    return OrderItem.fromJson({
      ...row,
      'product_name': name,
      'thumbnail': firstImage,
    });
  }

  @override
  Future<Result<Order>> confirm(String id) =>
      _transition(id, OrderStatus.confirmed);

  @override
  Future<Result<Order>> markPreparing(String id) =>
      _transition(id, OrderStatus.preparing);

  @override
  Future<Result<Order>> markShipped(String id) =>
      _transition(id, OrderStatus.shipped);

  @override
  Future<Result<Order>> markDelivered(String id) =>
      _transition(id, OrderStatus.delivered);

  @override
  Future<Result<Order>> cancel(String id, {required String reason}) =>
      _transition(id, OrderStatus.cancelled, cancelReason: reason);

  @override
  Future<Result<Order>> proposeDeliveryFee(
    String id, {
    required num fee,
    String? note,
  }) =>
      runCatching(() async {
        final rows = await _client.from(_ordersTable).update({
          'proposed_delivery_fee': fee,
          'fee_adjustment_note': note,
          'fee_adjustment_status': 'pending_customer',
        }).eq('id', id).select();
        if (rows.isEmpty) {
          throw const ServerFailure(
            message: "Yetkazish narxini o'zgartirib bo'lmadi",
          );
        }
        return _fetchOrder(id);
      });

  /// Applies a status update and returns the refreshed order. Row-level
  /// access is scoped by the seller RLS policies on `orders`; the value
  /// surfaced is whatever the updated row resolves to.
  Future<Result<Order>> _transition(
    String id,
    OrderStatus next, {
    String? cancelReason,
  }) =>
      runCatching(() async {
        final payload = <String, dynamic>{
          'status': next.code,
          // Live column is `cancellation_reason`; the null-aware entry is
          // omitted entirely for non-cancel transitions.
          'cancellation_reason': ?cancelReason,
        };
        final rows = await _client
            .from(_ordersTable)
            .update(payload)
            .eq('id', id)
            .select();
        if (rows.isEmpty) {
          throw const ServerFailure(
            message: "Buyurtma holatini o'zgartirib bo'lmadi",
          );
        }
        return _fetchOrder(id);
      });

  // The channel is opened/closed by the controller's onListen/onCancel hooks
  // (see the constructor) — listening starts it, the last cancel tears it
  // down.
  @override
  Stream<Order> newOrders() => _newOrders.stream;

  /// Broadcast feed of order updates the seller can read.
  ///
  /// Drives the orders list bloc's update path so customer-side cancels
  /// (or status flips from another seller session) flow back without a
  /// manual refresh. The repository owns the channel lifetime; the
  /// controller's listener hooks bring the socket up and tear it down so
  /// no websocket leaks across a mode switch.
  @override
  Stream<Order> orderUpdates() => _orderUpdates.stream;

  Future<void> _teardownNewOrdersSubscription() async {
    final sub = _newOrdersSub;
    _newOrdersSub = null;
    await sub?.close();
  }

  Future<void> _teardownUpdatesSubscription() async {
    final sub = _updatesSub;
    _updatesSub = null;
    await sub?.close();
  }

  Future<void> _ensureUpdatesSubscription() async {
    if (_disposed || _updatesSub != null || _updatesSubscribing) return;
    _updatesSubscribing = true;
    try {
      final shopId = await _fetchShopIdOrNull();
      if (shopId == null || _disposed || _updatesSub != null) return;
      _updatesSub = _realtime.subscribe(
        channelName: 'seller-orders-updates-$shopId',
        table: _ordersTable,
        onUpdate: (_, row) => unawaited(_handleOrderUpdate(row, shopId)),
      );
    } catch (e, st) {
      talker.handle(
        e,
        st,
        'SupabaseSellerOrderRepository.subscribeUpdates',
      );
    } finally {
      _updatesSubscribing = false;
    }
  }

  /// Same ownership confirmation as [_handleOrderInsert] — the realtime
  /// payload doesn't carry shop_id, so a row UPDATE only reaches the
  /// stream once we verify the order contains at least one product from
  /// this seller's shop.
  Future<void> _handleOrderUpdate(RealtimeRow row, String shopId) async {
    try {
      final id = row['id'] as String?;
      if (id == null || _orderUpdates.isClosed) return;
      if (!await _orderBelongsToShop(id, shopId)) return;
      final order = await _fetchOrder(id);
      if (!_orderUpdates.isClosed) _orderUpdates.add(order);
    } catch (e, st) {
      talker.handle(
        e,
        st,
        'SupabaseSellerOrderRepository._handleOrderUpdate',
      );
    }
  }

  Future<void> _ensureNewOrdersSubscription() async {
    if (_disposed || _newOrdersSub != null || _subscribing) return;
    _subscribing = true;
    try {
      final shopId = await _fetchShopIdOrNull();
      if (shopId == null || _disposed || _newOrdersSub != null) return;
      _newOrdersSub = _realtime.subscribe(
        channelName: 'seller-orders-$shopId',
        table: _ordersTable,
        filter: const RealtimeFilter.eq('status', 'pending'),
        onInsert: (row) => unawaited(_handleOrderInsert(row, shopId)),
      );
    } catch (e, st) {
      talker.handle(e, st, 'SupabaseSellerOrderRepository.subscribe');
    } finally {
      _subscribing = false;
    }
  }

  /// `orders` carries no `shop_id`, so a realtime insert must be confirmed to
  /// belong to this shop before it reaches the [newOrders] stream.
  Future<void> _handleOrderInsert(RealtimeRow row, String shopId) async {
    try {
      final id = row['id'] as String?;
      if (id == null || _newOrders.isClosed) return;
      if (!await _orderBelongsToShop(id, shopId)) return;
      final order = await _fetchOrder(id);
      if (!_newOrders.isClosed) _newOrders.add(order);
    } catch (e, st) {
      talker.handle(e, st, 'SupabaseSellerOrderRepository._handleOrderInsert');
    }
  }

  @override
  Stream<Order> watch(String orderId) {
    final controller = StreamController<Order>();
    RealtimeSubscription? sub;
    controller
      ..onListen = () {
        sub = _realtime.subscribe(
          // Unique per call — two detail screens on the same order must not
          // collide on the channel name.
          channelName: 'seller-order-watch-${_watchSeq++}',
          table: _ordersTable,
          filter: RealtimeFilter.eq('id', orderId),
          onUpdate: (_, _) => unawaited(_emitWatched(orderId, controller)),
        );
      }
      ..onCancel = () async {
        await sub?.close();
        if (!controller.isClosed) await controller.close();
      };
    return controller.stream;
  }

  Future<void> _emitWatched(
    String orderId,
    StreamController<Order> controller,
  ) async {
    try {
      final order = await _fetchOrder(orderId);
      if (!controller.isClosed) controller.add(order);
    } catch (e, st) {
      talker.handle(e, st, 'SupabaseSellerOrderRepository._emitWatched');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _newOrdersSub?.close();
    await _updatesSub?.close();
    if (!_newOrders.isClosed) await _newOrders.close();
    if (!_orderUpdates.isClosed) await _orderUpdates.close();
  }

  // ─── Shop / ownership helpers ───────────────────────────────────────────

  Future<String> _requireShopId() async {
    final shopId = await _fetchShopIdOrNull();
    if (shopId == null) {
      throw const ServerFailure(message: "Do'kon topilmadi");
    }
    return shopId;
  }

  Future<String?> _fetchShopIdOrNull() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('shops')
        .select('id')
        .eq('seller_id', userId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  /// Distinct order ids that contain at least one of the shop's products.
  Future<List<String>> _orderIdsForShop(
    String shopId, {
    int limit = 500,
  }) async {
    final productRows =
        await _client.from('products').select('id').eq('shop_id', shopId);
    final productIds =
        productRows.map<String>((r) => r['id'] as String).toList();
    if (productIds.isEmpty) return const [];
    final itemRows = await _client
        .from(_itemsTable)
        .select('order_id')
        .inFilter('product_id', productIds)
        .limit(limit);
    return <String>{
      for (final r in itemRows)
        if (r['order_id'] is String) r['order_id'] as String,
    }.toList(growable: false);
  }

  Future<bool> _orderBelongsToShop(String orderId, String shopId) async {
    final itemRows = await _client
        .from(_itemsTable)
        .select('product_id')
        .eq('order_id', orderId);
    final productIds =
        itemRows.map((r) => r['product_id']).whereType<String>().toList();
    if (productIds.isEmpty) return false;
    final ownRows = await _client
        .from('products')
        .select('id')
        .eq('shop_id', shopId)
        .inFilter('id', productIds)
        .limit(1);
    return ownRows.isNotEmpty;
  }
}
