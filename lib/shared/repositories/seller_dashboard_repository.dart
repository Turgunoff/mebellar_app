
import '../models/dashboard_snapshot.dart';
import '../models/order.dart';

abstract class SellerDashboardRepository {
  Future<DashboardSnapshot> snapshot();

  /// Full weekly board (`GET /seller/leaderboard`) — top N + `my_rank`.
  Future<LeaderboardBoard> fetchLeaderboard({int limit = 20});

  /// Seller display identity for the greeting — `legal_name` + `shop_name`
  /// from `GET /seller/me`. The dashboard fetches this itself so the greeting
  /// is correct on the very first load after sign-in, instead of depending on
  /// the profile tab having populated the shared identity cache first.
  Future<({String? sellerName, String? shopName})> identity();

  /// Realtime: emits when a new (pending) order arrives. Mock variant fires
  /// every ~25 sek so the UI haptic + snackbar can be exercised in dev.
  Stream<Order> newOrders();
}
