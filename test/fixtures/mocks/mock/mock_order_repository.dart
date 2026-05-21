import 'dart:async';
import 'dart:math' as math;

import 'package:woody_app/shared/models/order.dart';
import 'package:woody_app/shared/models/order_status.dart';
import 'package:woody_app/shared/repositories/order_repository.dart';
import 'mock_orders_data.dart';

/// Stateful mock used by orders list, order detail, and the realtime
/// progression stream. Newly created orders advance through pending →
/// confirmed → preparing every ~6 seconds so a tester can see the timeline
/// fill up live without a real backend.
class MockOrderRepository implements OrderRepository {
  static const _delay = Duration(milliseconds: 220);

  final List<Order> _orders = List<Order>.from(MockOrdersData.orders);
  final Map<String, StreamController<Order>> _watchers = {};
  int _idCounter = 1003;
  int _orderNumberCounter = 3;

  @override
  Future<List<Order>> list() async {
    await Future<void>.delayed(_delay);
    final sorted = List<Order>.from(_orders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<Order> getById(String id) async {
    await Future<void>.delayed(_delay);
    final order = _orders.where((o) => o.id == id).firstOrNull;
    if (order == null) throw StateError('Buyurtma topilmadi: $id');
    return order;
  }

  @override
  Future<Order> create(CreateOrderInput input) async {
    await Future<void>.delayed(_delay);

    // 5% chance of insufficient_stock to exercise checkout error UX.
    final rand = math.Random();
    if (rand.nextDouble() < 0.05) {
      throw StateError('insufficient_stock');
    }

    final items = input.items
        .map((it) => OrderItem(
              productId: it.product.id,
              productSlug: it.product.slug,
              productName: it.product.name,
              thumbnail: it.product.heroImage,
              unitPrice: it.product.price,
              quantity: it.quantity,
            ))
        .toList();
    final itemsTotal = items.fold<num>(0, (sum, it) => sum + it.lineTotal);
    final delivery = input.deliveryMethod == OrderDeliveryMethod.pickup
        ? 0
        : (input.deliveryMethod == OrderDeliveryMethod.expressDelivery
            ? 80000
            : 50000);
    final now = DateTime.now();
    _idCounter += 1;
    _orderNumberCounter += 1;
    final order = Order(
      id: 'ord-$_idCounter',
      orderNumber: 'M-2026-${_orderNumberCounter.toString().padLeft(3, '0')}',
      shop: input.shop,
      items: items,
      address: input.address,
      deliveryMethod: input.deliveryMethod,
      paymentMethod: input.paymentMethod,
      status: OrderStatus.pending,
      itemsTotal: itemsTotal,
      deliveryFee: delivery,
      servicesFee: 0,
      grandTotal: itemsTotal + delivery,
      createdAt: now,
      expectedDeliveryAt: input.deliveryMethod == OrderDeliveryMethod.pickup
          ? null
          : now.add(const Duration(days: 3)),
      timeline: [
        OrderStatusEvent(status: OrderStatus.pending, timestamp: now),
      ],
    );
    _orders.insert(0, order);
    _scheduleProgression(order.id);
    return order;
  }

  @override
  Future<Order> cancel(String id, {required String reason}) async {
    await Future<void>.delayed(_delay);
    final idx = _orders.indexWhere((o) => o.id == id);
    if (idx < 0) throw StateError('Buyurtma topilmadi: $id');
    final order = _orders[idx];
    final updated = order.copyWith(
      status: OrderStatus.cancelled,
      cancelReason: reason,
      timeline: [
        ...order.timeline,
        OrderStatusEvent(
          status: OrderStatus.cancelled,
          timestamp: DateTime.now(),
          note: reason,
        ),
      ],
    );
    _orders[idx] = updated;
    _watchers[id]?.add(updated);
    return updated;
  }

  @override
  Stream<Order> watch(String orderId) {
    final controller = _watchers.putIfAbsent(
      orderId,
      () => StreamController<Order>.broadcast(),
    );
    return controller.stream;
  }

  /// Progression: pending → confirmed (after 8s) → preparing (after 8s more).
  /// We stop there for fresh orders so the user sees the timeline grow
  /// without auto-completing every order.
  void _scheduleProgression(String orderId) {
    Future<void>.delayed(const Duration(seconds: 8), () {
      _advance(orderId, OrderStatus.confirmed);
      Future<void>.delayed(const Duration(seconds: 8), () {
        _advance(orderId, OrderStatus.preparing);
      });
    });
  }

  void _advance(String orderId, OrderStatus next) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return;
    final order = _orders[idx];
    if (order.status.isTerminal) return;
    final updated = order.copyWith(
      status: next,
      timeline: [
        ...order.timeline,
        OrderStatusEvent(status: next, timestamp: DateTime.now()),
      ],
    );
    _orders[idx] = updated;
    _watchers[orderId]?.add(updated);
  }
}
