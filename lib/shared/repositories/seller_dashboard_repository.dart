
import '../models/dashboard_snapshot.dart';
import '../models/order.dart';

abstract class SellerDashboardRepository {
  Future<DashboardSnapshot> snapshot();

  /// Realtime: emits when a new (pending) order arrives. Mock variant fires
  /// every ~25 sek so the UI haptic + snackbar can be exercised in dev.
  Stream<Order> newOrders();
}
