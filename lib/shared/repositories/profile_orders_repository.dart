import '../../core/network/woody_api_client.dart';
import '../models/cancel_reason.dart';

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

  /// `POST /orders/{id}/cancel` with a structured reason: a [reasonCode] from
  /// [fetchCancelReasons] plus free [reasonText] (required only when the code
  /// is `other`). The backend enforces customer cancel is pending-only.
  Future<void> cancel(
    String orderId, {
    required String reasonCode,
    String? reasonText,
  });

  /// Predefined customer cancellation reasons, localised by the active locale
  /// (the API client stamps `Accept-Language`).
  Future<List<CancelReason>> fetchCancelReasons();
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
  Future<void> cancel(
    String orderId, {
    required String reasonCode,
    String? reasonText,
  }) => _api.post<dynamic>(
    '/orders/$orderId/cancel',
    body: {
      'cancel_reason_code': reasonCode,
      if (reasonText != null && reasonText.isNotEmpty)
        'cancel_reason_text': reasonText,
    },
  );

  @override
  Future<List<CancelReason>> fetchCancelReasons() async {
    final rows = await _api.get<List<dynamic>>(
      '/orders/cancel-reasons',
      query: const {'role': 'customer'},
      retries: 2,
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CancelReason.fromJson)
        .toList(growable: false);
  }
}
