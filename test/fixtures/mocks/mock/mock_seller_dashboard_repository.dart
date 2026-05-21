import 'dart:async';
import 'dart:math' as math;

import 'package:woody_app/shared/models/dashboard_snapshot.dart';
import 'package:woody_app/shared/models/order.dart';
import 'package:woody_app/shared/models/order_status.dart';
import 'package:woody_app/shared/models/seller_product.dart';
import 'package:woody_app/shared/models/tariff.dart';
import 'package:woody_app/shared/repositories/seller_dashboard_repository.dart';
import 'mock_orders_data.dart';
import 'mock_seller_product_repository.dart';
import 'mock_seller_products.dart';

class MockSellerDashboardRepository implements SellerDashboardRepository {
  MockSellerDashboardRepository({
    required MockSellerProductRepository productRepo,
  }) : _productRepo = productRepo {
    // Synthesise a recurring "new order" so the seller dashboard listener
    // has something to react to during demos. We pick one of the seeded
    // orders and bump it to pending for the simulation.
    _timer = Timer.periodic(const Duration(seconds: 25), _emitFakeNewOrder);
  }

  final MockSellerProductRepository _productRepo;
  final _orderController = StreamController<Order>.broadcast();
  Timer? _timer;

  @override
  Future<DashboardSnapshot> snapshot() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final orders = MockOrdersData.orders;
    final today = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;
    final todays = orders.where((o) => isToday(o.createdAt)).toList();
    final pending = orders
        .where((o) => o.status == OrderStatus.pending)
        .length;
    final activeProducts = MockSellerProducts.products
        .where((p) =>
            p.status == SellerProductStatus.approved ||
            p.status == SellerProductStatus.pendingReview)
        .length;
    final tariff = TariffSnapshot(
      plan: TariffPlan.free,
      activeProductsCount: _productRepo.activeProductsCount > 0
          ? _productRepo.activeProductsCount
          : activeProducts,
    );
    return DashboardSnapshot(
      todaysOrders: todays.length,
      todaysRevenue: todays.fold<num>(0, (sum, o) => sum + o.grandTotal),
      pendingOrdersCount: pending,
      activeProductsCount: tariff.activeProductsCount,
      tariff: tariff,
      recentOrders: orders.take(5).toList(),
      last30Days: [
        for (final p in MockSellerProducts.revenueSeries())
          DailyRevenuePoint(date: p.date, amount: p.amount),
      ],
    );
  }

  @override
  Stream<Order> newOrders() => _orderController.stream;

  void _emitFakeNewOrder(Timer _) {
    if (_orderController.isClosed) return;
    if (MockOrdersData.orders.isEmpty) return;
    final rand = math.Random();
    final base = MockOrdersData.orders[
        rand.nextInt(MockOrdersData.orders.length)];
    final fakeNew = Order(
      id: 'ord-fake-${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: 'M-${DateTime.now().year}-FAKE-${rand.nextInt(999)}',
      shop: base.shop,
      items: base.items,
      address: base.address,
      deliveryMethod: base.deliveryMethod,
      paymentMethod: base.paymentMethod,
      status: OrderStatus.pending,
      itemsTotal: base.itemsTotal,
      deliveryFee: base.deliveryFee,
      servicesFee: base.servicesFee,
      grandTotal: base.grandTotal,
      createdAt: DateTime.now(),
      timeline: [
        OrderStatusEvent(
          status: OrderStatus.pending,
          timestamp: DateTime.now(),
        ),
      ],
    );
    _orderController.add(fakeNew);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    if (!_orderController.isClosed) {
      await _orderController.close();
    }
  }
}
