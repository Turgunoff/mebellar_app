import 'package:dio/dio.dart';

import '../models/order.dart';
import '../models/order_status.dart';

/// Seller-side actions on an order. The customer-side `OrderRepository` only
/// supports cancel + watch; this one adds the workflow transitions sellers
/// drive (confirm → preparing → shipped → delivered) plus a stream of newly
/// inserted pending orders so the orders list can update without re-fetching.
abstract class SellerOrderRepository {
  Future<List<Order>> list();
  Future<Order> getById(String id);

  /// Stream of newly pending orders (mock variant: same one as
  /// `SellerDashboardRepository.newOrders` so the realtime cue is consistent
  /// across screens).
  Stream<Order> newOrders();

  /// State-machine transitions. Each enforces the legal source statuses on
  /// the backend; the mock variant mirrors the same checks so the UI gets
  /// the same `StateError` it would get in production.
  Future<Order> confirm(String id);
  Future<Order> markPreparing(String id);
  Future<Order> markShipped(String id);
  Future<Order> markDelivered(String id);
  Future<Order> cancel(String id, {required String reason});

  Stream<Order> watch(String orderId);
}

class RemoteSellerOrderRepository implements SellerOrderRepository {
  RemoteSellerOrderRepository(this._dio);
  // ignore: unused_field — Sprint 8 backend wires real endpoints.
  final Dio _dio;

  @override
  Future<List<Order>> list() =>
      throw UnimplementedError('Remote seller orders — Sprint 8 backend');

  @override
  Future<Order> getById(String id) =>
      throw UnimplementedError('Remote seller orders — Sprint 8 backend');

  @override
  Stream<Order> newOrders() => const Stream.empty();

  @override
  Future<Order> confirm(String id) =>
      throw UnimplementedError('Remote seller orders — Sprint 8 backend');

  @override
  Future<Order> markPreparing(String id) =>
      throw UnimplementedError('Remote seller orders — Sprint 8 backend');

  @override
  Future<Order> markShipped(String id) =>
      throw UnimplementedError('Remote seller orders — Sprint 8 backend');

  @override
  Future<Order> markDelivered(String id) =>
      throw UnimplementedError('Remote seller orders — Sprint 8 backend');

  @override
  Future<Order> cancel(String id, {required String reason}) =>
      throw UnimplementedError('Remote seller orders — Sprint 8 backend');

  @override
  Stream<Order> watch(String orderId) => const Stream.empty();
}

/// Mapping helper used by the action buttons widget — keeps the legal
/// transition table next to the seller-only repository it drives.
extension SellerOrderTransitions on OrderStatus {
  /// Allowed forward transitions a seller can trigger from this state.
  /// `cancel` is allowed from any non-terminal state and is treated
  /// separately by the UI.
  List<OrderStatus> get sellerForwardTransitions {
    return switch (this) {
      OrderStatus.pending => [OrderStatus.confirmed],
      OrderStatus.confirmed => [OrderStatus.preparing, OrderStatus.shipped],
      OrderStatus.preparing => [OrderStatus.shipped],
      OrderStatus.shipped => [OrderStatus.delivered],
      OrderStatus.delivered || OrderStatus.cancelled => const [],
    };
  }
}
