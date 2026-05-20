import 'dart:async';

import 'package:clock/clock.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../repositories/seller_order_repository.dart';
import 'mock_orders_data.dart';

/// In-memory seller-side order book. The dashboard's fake "new order" timer
/// (Sprint 7) feeds this repository so the orders list reflects the same
/// transient inserts.
class MockSellerOrderRepository implements SellerOrderRepository {
  MockSellerOrderRepository() {
    _orders.addAll(MockOrdersData.orders);
    // Recurrent simulated insert — same cadence as the dashboard listener so
    // the orders list and the dashboard "Yangi orderlar" stay in sync.
    _timer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _injectNewOrder(),
    );
  }

  static const _delay = Duration(milliseconds: 250);

  final List<Order> _orders = [];
  final Map<String, StreamController<Order>> _watchers = {};
  final _newOrders = StreamController<Order>.broadcast();
  // Mock has no real realtime UPDATE channel — transitions are emitted
  // here so the orders list bloc behaves the same against the mock as it
  // does against Supabase (the live impl emits on every server UPDATE).
  final _orderUpdates = StreamController<Order>.broadcast();
  Timer? _timer;
  int _idCounter = 1100;

  @override
  Future<Result<List<Order>>> list() async {
    await Future<void>.delayed(_delay);
    final sorted = List<Order>.from(_orders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Ok(sorted);
  }

  @override
  Future<Result<Order>> getById(String id) async {
    await Future<void>.delayed(_delay);
    final order = _orders.where((o) => o.id == id).firstOrNull;
    if (order == null) {
      return Err(ServerFailure(message: 'Buyurtma topilmadi: $id'));
    }
    return Ok(order);
  }

  @override
  Stream<Order> newOrders() => _newOrders.stream;

  @override
  Stream<Order> orderUpdates() => _orderUpdates.stream;

  @override
  Future<Result<Order>> confirm(String id) =>
      _transition(id, from: {OrderStatus.pending}, to: OrderStatus.confirmed);

  @override
  Future<Result<Order>> markPreparing(String id) => _transition(
        id,
        from: {OrderStatus.confirmed},
        to: OrderStatus.preparing,
      );

  @override
  Future<Result<Order>> markShipped(String id) => _transition(
        id,
        from: {OrderStatus.confirmed, OrderStatus.preparing},
        to: OrderStatus.shipped,
      );

  @override
  Future<Result<Order>> markDelivered(String id) => _transition(
        id,
        from: {OrderStatus.shipped},
        to: OrderStatus.delivered,
      );

  @override
  Future<Result<Order>> cancel(String id, {required String reason}) async {
    await Future<void>.delayed(_delay);
    final idx = _orders.indexWhere((o) => o.id == id);
    if (idx < 0) {
      return Err(ServerFailure(message: 'Buyurtma topilmadi: $id'));
    }
    final order = _orders[idx];
    if (order.status.isTerminal) {
      return Err(ServerFailure(
        message: "Bu buyurtmani bekor qilib bo'lmaydi (${order.status.code})",
      ));
    }
    final updated = order.copyWith(
      status: OrderStatus.cancelled,
      cancelReason: reason,
      timeline: [
        ...order.timeline,
        OrderStatusEvent(
          status: OrderStatus.cancelled,
          timestamp: clock.now(),
          note: reason,
        ),
      ],
    );
    _orders[idx] = updated;
    _watchers[id]?.add(updated);
    if (!_orderUpdates.isClosed) _orderUpdates.add(updated);
    return Ok(updated);
  }

  @override
  Stream<Order> watch(String orderId) {
    final controller = _watchers.putIfAbsent(
      orderId,
      () => StreamController<Order>.broadcast(),
    );
    return controller.stream;
  }

  Future<Result<Order>> _transition(
    String id, {
    required Set<OrderStatus> from,
    required OrderStatus to,
  }) async {
    await Future<void>.delayed(_delay);
    final idx = _orders.indexWhere((o) => o.id == id);
    if (idx < 0) {
      return Err(ServerFailure(message: 'Buyurtma topilmadi: $id'));
    }
    final order = _orders[idx];
    if (!from.contains(order.status)) {
      return Err(ServerFailure(
        message:
            "Joriy holatdan o'tib bo'lmaydi (${order.status.code} → ${to.code})",
      ));
    }
    final updated = order.copyWith(
      status: to,
      timeline: [
        ...order.timeline,
        OrderStatusEvent(status: to, timestamp: clock.now()),
      ],
    );
    _orders[idx] = updated;
    _watchers[id]?.add(updated);
    if (!_orderUpdates.isClosed) _orderUpdates.add(updated);
    return Ok(updated);
  }

  /// Generates a fresh pending order from a seed template. Used both by the
  /// timer-driven simulation and the dashboard listener so demos see live
  /// inserts without manual seeding.
  void _injectNewOrder() {
    if (_newOrders.isClosed) return;
    if (MockOrdersData.orders.isEmpty) return;
    final template = MockOrdersData.orders.first;
    _idCounter += 1;
    final id = 'ord-mock-$_idCounter';
    final fake = Order(
      id: id,
      orderNumber: 'M-${clock.now().year}-NEW-$_idCounter',
      shop: template.shop,
      items: template.items,
      address: template.address,
      deliveryMethod: template.deliveryMethod,
      paymentMethod: template.paymentMethod,
      status: OrderStatus.pending,
      itemsTotal: template.itemsTotal,
      deliveryFee: template.deliveryFee,
      servicesFee: template.servicesFee,
      grandTotal: template.grandTotal,
      createdAt: clock.now(),
      timeline: [
        OrderStatusEvent(
          status: OrderStatus.pending,
          timestamp: clock.now(),
        ),
      ],
    );
    _orders.insert(0, fake);
    _newOrders.add(fake);
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    if (!_newOrders.isClosed) {
      await _newOrders.close();
    }
    if (!_orderUpdates.isClosed) {
      await _orderUpdates.close();
    }
    for (final c in _watchers.values) {
      if (!c.isClosed) await c.close();
    }
    _watchers.clear();
  }
}
