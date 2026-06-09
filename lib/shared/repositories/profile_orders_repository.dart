import '../../core/network/woody_api_client.dart';

/// Backs [ProfileOrdersCubit]: the signed-in customer's own order list plus
/// cancel. A thin seam over [WoodyApiClient] so the cubit is unit-testable
/// without a live HTTP client and stops reaching into the network layer
/// directly — matching every other customer cubit, which depend on a
/// repository interface rather than [WoodyApiClient].
///
/// Returns raw woody_backend rows (the cubit maps them to the
/// history-card shape) rather than typed `Order` models, because the order
/// history UI consumes that legacy PostgREST-shaped map.
abstract class ProfileOrdersRepository {
  /// `GET /orders` → the `rows` array as raw maps. Empty when absent.
  Future<List<Map<String, dynamic>>> fetchOrders();

  /// `POST /orders/{id}/cancel` with the customer-supplied [reason].
  Future<void> cancel(String orderId, String reason);
}

class WoodyProfileOrdersRepository implements ProfileOrdersRepository {
  WoodyProfileOrdersRepository(this._api);

  final WoodyApiClient _api;

  @override
  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final body = await _api.get<Map<String, dynamic>>('/orders');
    final rows = body['rows'];
    return rows is List
        ? rows.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  @override
  Future<void> cancel(String orderId, String reason) =>
      _api.post<dynamic>('/orders/$orderId/cancel', body: {'reason': reason});
}
