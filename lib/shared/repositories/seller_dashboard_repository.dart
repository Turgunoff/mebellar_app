import 'package:dio/dio.dart';

import '../models/dashboard_snapshot.dart';
import '../models/order.dart';

abstract class SellerDashboardRepository {
  Future<DashboardSnapshot> snapshot();

  /// Realtime: emits when a new (pending) order arrives. Mock variant fires
  /// every ~25 sek so the UI haptic + snackbar can be exercised in dev.
  Stream<Order> newOrders();
}

class RemoteSellerDashboardRepository implements SellerDashboardRepository {
  RemoteSellerDashboardRepository(this._dio);
  // ignore: unused_field — Sprint 7 backend wires real endpoint.
  final Dio _dio;

  @override
  Future<DashboardSnapshot> snapshot() =>
      throw UnimplementedError('Remote dashboard — Sprint 7 backend');

  @override
  Stream<Order> newOrders() => const Stream.empty();
}
