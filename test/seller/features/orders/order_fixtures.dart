import 'package:woody_app/shared/models/order.dart';
import 'package:woody_app/shared/models/order_status.dart';

/// Builds a minimal [Order] for tests. Every property has a sane default so
/// each test only specifies the fields it actually exercises (id, status,
/// createdAt). Sub-aggregates (shop, address, items, timeline) fall back to
/// the same placeholders `Order.fromJson` uses, which is what the seller
/// list / detail screens consume.
Order makeOrder({
  String id = 'order-1',
  OrderStatus status = OrderStatus.pending,
  DateTime? createdAt,
  num grandTotal = 100,
  String? cancelReason,
}) {
  // `Order.fromJson` already wires placeholder shop/address when omitted,
  // and constructs the synthesised `orderNumber` from the id. Going through
  // it keeps the fixture consistent with how production rows materialise.
  final row = <String, dynamic>{
    'id': id,
    'status': status.code,
    'total_amount': grandTotal,
    'created_at': (createdAt ?? DateTime(2026, 1, 1)).toIso8601String(),
    'cancellation_reason': ?cancelReason,
  };
  return Order.fromJson(row);
}
