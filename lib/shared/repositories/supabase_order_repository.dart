import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/address.dart';
import '../models/multilingual_text.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../models/region.dart';
import '../models/shop.dart';
import 'order_repository.dart';

/// Supabase-backed implementation of [OrderRepository].
///
/// Schema assumptions:
///   orders      : id, user_id, total_amount, status, created_at,
///                 delivery_address, cancellation_reason
///   order_items : id, order_id, product_id, quantity, price,
///                 products(id, name, images, shop_id)
///
/// Fields absent from the DB (delivery_method, payment_method, timeline, etc.)
/// are derived or given sensible defaults so the Order model remains fully
/// populated for the UI.
class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(this._supabase);

  final SupabaseClient _supabase;

  static const _select =
      '*, order_items(id, product_id, quantity, price, color_slug, '
      'products(id, name, images, shop_id))';

  String? get _userId => _supabase.auth.currentUser?.id;

  // ─── Public API ─────────────────────────────────────────────────────────────

  @override
  Future<List<Order>> list() async {
    final userId = _userId;
    if (userId == null) return [];
    final rows = await _supabase
        .from('orders')
        .select(_select)
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map<Order>(_rowToOrder).toList();
  }

  @override
  Future<Order> getById(String id) async {
    final row = await _supabase
        .from('orders')
        .select(_select)
        .eq('id', id)
        .single();
    return _rowToOrder(row);
  }

  @override
  Future<Order> create(CreateOrderInput input) async {
    final userId = _userId;
    if (userId == null) throw StateError('Not authenticated');

    final itemsTotal = input.items.fold<num>(
      0,
      (s, it) => s + it.product.price * it.quantity,
    );
    final deliveryFee = _deliveryFee(input.deliveryMethod);
    final grandTotal = itemsTotal + deliveryFee;

    final orderRow = await _supabase
        .from('orders')
        .insert({
          'user_id': userId,
          'total_amount': grandTotal,
          'status': OrderStatus.pending.code,
          'delivery_address': input.address.formatted('uz'),
        })
        .select('id, created_at')
        .single();

    final orderId = orderRow['id'] as String;
    final createdAt = DateTime.parse(orderRow['created_at'] as String);

    await _supabase.from('order_items').insert([
      for (final it in input.items)
        {
          'order_id': orderId,
          'product_id': it.product.id,
          'quantity': it.quantity,
          'price': it.product.price,
        },
    ]);

    final orderItems = input.items
        .map(
          (it) => OrderItem(
            productId: it.product.id,
            productSlug: it.product.slug,
            productName: it.product.name,
            thumbnail: it.product.heroImage,
            unitPrice: it.product.price,
            quantity: it.quantity,
          ),
        )
        .toList();

    return Order(
      id: orderId,
      orderNumber: _orderNumber(orderId),
      shop: input.shop,
      items: orderItems,
      address: input.address,
      deliveryMethod: input.deliveryMethod,
      paymentMethod: input.paymentMethod,
      status: OrderStatus.pending,
      itemsTotal: itemsTotal,
      deliveryFee: deliveryFee,
      servicesFee: 0,
      grandTotal: grandTotal,
      createdAt: createdAt,
      expectedDeliveryAt: input.deliveryMethod == OrderDeliveryMethod.pickup
          ? null
          : createdAt.add(const Duration(days: 3)),
      timeline: [
        OrderStatusEvent(status: OrderStatus.pending, timestamp: createdAt),
      ],
    );
  }

  @override
  Future<Order> cancel(String id, {required String reason}) async {
    await _supabase
        .from('orders')
        .update({
          'status': OrderStatus.cancelled.code,
          'cancellation_reason': reason,
        })
        .eq('id', id);
    return getById(id);
  }

  @override
  Future<Order> approveFeeAdjustment(String id) async {
    // Re-fetch to get the proposed_delivery_fee before we commit it.
    final current = await getById(id);
    final proposed = current.proposedDeliveryFee;
    if (proposed == null) return current;
    final newTotal = current.itemsTotal + proposed;
    await _supabase
        .from('orders')
        .update({
          'total_amount': newTotal,
          'fee_adjustment_status': 'approved',
          'proposed_delivery_fee': null,
          'fee_adjustment_note': null,
        })
        .eq('id', id);
    return getById(id);
  }

  @override
  Future<Order> rejectFeeAdjustment(String id) async {
    await _supabase
        .from('orders')
        .update({'fee_adjustment_status': 'rejected'})
        .eq('id', id);
    return getById(id);
  }

  /// Streams order updates via Supabase Realtime. On each row change the full
  /// order (with items) is re-fetched so the UI always gets a complete object.
  @override
  Stream<Order> watch(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .asyncMap((_) => getById(orderId));
  }

  // ─── Mapping helpers ─────────────────────────────────────────────────────────

  Order _rowToOrder(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final status = OrderStatus.fromCode(row['status'] as String?);
    final createdAt = DateTime.parse(row['created_at'] as String);
    final totalAmount = (row['total_amount'] as num?) ?? 0;

    final itemRows = (row['order_items'] as List<dynamic>?) ?? [];
    final items = itemRows.map<OrderItem>(_rowToOrderItem).toList();

    final itemsTotal = items.fold<num>(0, (s, it) => s + it.lineTotal);
    // Delivery fee is whatever is left above the items total.
    final deliveryFee = totalAmount > itemsTotal ? totalAmount - itemsTotal : 0;

    // Best-effort: pick shop_id from the first order item's product.
    Shop shop = _unknownShop;
    for (final raw in itemRows) {
      final productRow =
          (raw as Map<String, dynamic>)['products'] as Map<String, dynamic>?;
      final shopId = productRow?['shop_id'] as String?;
      if (shopId != null) {
        shop = Shop(
          id: shopId,
          slug: shopId,
          name: const MultilingualText(uz: "Do'kon", ru: 'Магазин', en: 'Shop'),
        );
        break;
      }
    }

    return Order(
      id: id,
      orderNumber: _orderNumber(id),
      shop: shop,
      items: items,
      address: _addressFromText(row['delivery_address'] as String?, id),
      deliveryMethod: OrderDeliveryMethod.delivery,
      paymentMethod: OrderPaymentMethod.cashOnDelivery,
      status: status,
      itemsTotal: itemsTotal,
      deliveryFee: deliveryFee,
      servicesFee: 0,
      grandTotal: totalAmount,
      createdAt: createdAt,
      timeline: _syntheticTimeline(status, createdAt),
      cancelReason: row['cancellation_reason'] as String?,
      proposedDeliveryFee: row['proposed_delivery_fee'] as num?,
      feeAdjustmentNote: row['fee_adjustment_note'] as String?,
      feeAdjustmentStatus: FeeAdjustmentStatus.fromCode(
        row['fee_adjustment_status'] as String?,
      ),
    );
  }

  static OrderItem _rowToOrderItem(dynamic raw) {
    final row = raw as Map<String, dynamic>;
    final productRow = row['products'] as Map<String, dynamic>?;

    // products.name is stored as plain text in Supabase (not multilingual JSON).
    final rawName = productRow?['name'];
    final name = rawName is String ? rawName : '';

    final images = productRow?['images'] as List<dynamic>? ?? [];
    final thumbnail = images.isNotEmpty ? images.first as String : '';

    return OrderItem(
      id: row['id'] as String?,
      productId: row['product_id'] as String,
      productSlug: row['product_id'] as String,
      productName: MultilingualText(uz: name, ru: name, en: name),
      thumbnail: thumbnail,
      unitPrice: (row['price'] as num?) ?? 0,
      quantity: (row['quantity'] as int?) ?? 1,
      colorSlug: row['color_slug'] as String? ?? '',
    );
  }

  // ─── Pure helpers ─────────────────────────────────────────────────────────────

  static String _orderNumber(String id) =>
      'WD-${id.substring(0, 8).toUpperCase()}';

  static num _deliveryFee(OrderDeliveryMethod method) => switch (method) {
    OrderDeliveryMethod.pickup => 0,
    OrderDeliveryMethod.expressDelivery => 80000,
    OrderDeliveryMethod.delivery => 50000,
  };

  static Address _addressFromText(String? text, String orderId) => Address(
    id: 'addr-${orderId.substring(0, 8)}',
    label: 'Yetkazish manzili',
    recipientName: '',
    phone: '',
    region: _blankRegion,
    city: _blankRegion,
    streetLine: text ?? '',
  );

  /// Reconstructs a plausible status timeline from a single terminal status.
  /// Timestamps are synthetic (evenly spaced from createdAt) because the DB
  /// has no status-history table.
  static List<OrderStatusEvent> _syntheticTimeline(
    OrderStatus status,
    DateTime createdAt,
  ) {
    final events = [
      OrderStatusEvent(status: OrderStatus.pending, timestamp: createdAt),
    ];
    if (status == OrderStatus.pending) return events;

    if (status == OrderStatus.cancelled) {
      return [
        ...events,
        OrderStatusEvent(
          status: OrderStatus.cancelled,
          timestamp: createdAt.add(const Duration(hours: 1)),
        ),
      ];
    }

    const progression = [
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.shipped,
      OrderStatus.delivered,
    ];
    var t = createdAt;
    for (final s in progression) {
      t = t.add(const Duration(hours: 2));
      events.add(OrderStatusEvent(status: s, timestamp: t));
      if (s == status) break;
    }
    return events;
  }
}

const _blankRegion = Region(id: '_', code: '_', name: MultilingualText());

const _unknownShop = Shop(
  id: '_',
  slug: '_',
  name: MultilingualText(uz: "Do'kon", ru: 'Магазин', en: 'Shop'),
);
