import '../../core/network/woody_api_client.dart';
import '../../core/result/result.dart';
import '../models/address.dart';
import '../models/multilingual_text.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../models/region.dart';
import 'seller_order_repository.dart';

/// REST-backed [SellerOrderRepository] targeting `/seller/orders` on
/// api.woody.uz.
///
/// Backend shapes (see `app/domain/seller.py`):
/// ```
///   SellerOrder      id · status · total_amount · created_at ·
///                    delivery_address · customer_id · customer_name ·
///                    customer_phone · items[]
///   SellerOrderItem  id · product_id · product_name · product_image ·
///                    quantity · price · color_slug
///   SellerOrderList  rows[] · total
/// ```
/// The backend already scopes every order to the caller's shop (the router
/// resolves the shop via `_require_shop`), so unlike the legacy repo this
/// implementation does no client-side ownership filtering.
///
/// Degradations vs. the live implementation (see backendGaps):
///  - [proposeDeliveryFee] has no endpoint — returns [getById] unchanged.
///  - [newOrders]/[orderUpdates] have no realtime feed yet — empty streams.
///  - [watch] one-shot re-reads via [getById] (no live updates).
class WoodySellerOrderRepository implements SellerOrderRepository {
  WoodySellerOrderRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  static const String _ordersPath = '/seller/orders';

  @override
  Future<Result<List<Order>>> list() => runCatching(() async {
    final body = await _api.get<Map<String, dynamic>>(_ordersPath, retries: 2);
    final rows = (body['rows'] as List<dynamic>?) ?? const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_toOrder)
        .toList(growable: false);
  });

  @override
  Future<Result<Order>> getById(String id) =>
      runCatching(() => _fetchOrder(id));

  /// Reads a single order. The backend 404 surfaces as an [ApiError] thrown
  /// from the client, which [runCatching] funnels into an [Err].
  Future<Order> _fetchOrder(String id) async {
    final row = await _api.get<Map<String, dynamic>>('$_ordersPath/$id');
    return _toOrder(row);
  }

  @override
  Future<Result<Order>> confirm(String id) =>
      _transition(id, OrderStatus.confirmed);

  @override
  Future<Result<Order>> markPreparing(String id) =>
      _transition(id, OrderStatus.preparing);

  @override
  Future<Result<Order>> markShipped(String id) =>
      _transition(id, OrderStatus.shipped);

  @override
  Future<Result<Order>> markDelivered(String id) =>
      _transition(id, OrderStatus.delivered);

  @override
  Future<Result<Order>> cancel(String id, {required String reason}) =>
      _transition(id, OrderStatus.cancelled, cancelReason: reason);

  /// `PATCH /seller/orders/{id}/status` with a [SetOrderStatusBody] payload.
  /// The backend enforces the legal transition table and the accepted status
  /// set (`confirmed|preparing|shipped|delivered|cancelled`); an illegal
  /// transition or a missing order resolves to an [Err] via [runCatching].
  /// The endpoint returns the refreshed [SellerOrder], so no re-read is needed.
  Future<Result<Order>> _transition(
    String id,
    OrderStatus next, {
    String? cancelReason,
  }) => runCatching(() async {
    final row = await _api.patch<Map<String, dynamic>>(
      '$_ordersPath/$id/status',
      body: {
        'status': next.code,
        if (cancelReason != null) 'cancellation_reason': cancelReason,
      },
    );
    return _toOrder(row);
  });

  @override
  Future<Result<Order>> proposeDeliveryFee(
    String id, {
    required num fee,
    String? note,
  }) {
    // No backend endpoint for seller-proposed delivery-fee adjustments yet —
    // degrade to re-reading the order unchanged so callers still get a fresh
    // Result instead of an error. Tracked in backendGaps.
    return getById(id);
  }

  @override
  Stream<Order> newOrders() => const Stream.empty();

  @override
  Stream<Order> orderUpdates() => const Stream.empty();

  @override
  Stream<Order> watch(String orderId) =>
      Stream<Order>.fromFuture(_fetchOrder(orderId));

  @override
  Future<void> dispose() async {}

  /// Adapts a backend [SellerOrder] JSON row into the app's [Order]. The
  /// seller list/detail screens never render the shop card, so a placeholder
  /// shop is supplied by `Order.fromJson`; the buyer's contact info maps onto
  /// an [Address] from `customer_name` / `customer_phone` / `delivery_address`.
  Order _toOrder(Map<String, dynamic> row) {
    final id = row['id'] as String? ?? '';
    final itemsRaw = (row['items'] as List<dynamic>?) ?? const [];
    final items = itemsRaw
        .whereType<Map<String, dynamic>>()
        .map(_toOrderItem)
        .toList(growable: false);
    return Order.fromJson(
      row,
      items: items,
      address: _toAddress(id, row),
    );
  }

  /// Maps a backend [SellerOrderItem]. The backend's `product_image` carries
  /// the line thumbnail, so it's lifted onto `thumbnail`; `product_name` and
  /// `price`/`quantity`/`color_slug` map straight through `OrderItem.fromJson`.
  OrderItem _toOrderItem(Map<String, dynamic> row) {
    return OrderItem.fromJson({
      'id': row['id'],
      'product_id': row['product_id'],
      'product_name': row['product_name'] as String? ?? '',
      'thumbnail': row['product_image'] as String? ?? '',
      'price': row['price'],
      'quantity': row['quantity'],
      'color_slug': row['color_slug'] as String? ?? '',
    });
  }

  /// Builds the buyer's contact card from the flat order row. Mirrors the
  /// dashboard repo's address synthesis so the seller order-detail screen
  /// shows recipient name + phone + delivery address.
  Address _toAddress(String orderId, Map<String, dynamic> row) {
    final stub = orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
    return Address(
      id: 'addr-$stub',
      label: 'Yetkazish manzili',
      recipientName: row['customer_name'] as String? ?? '',
      phone: row['customer_phone'] as String? ?? '',
      region: const Region(id: '_', code: '_', name: MultilingualText()),
      city: const Region(id: '_', code: '_', name: MultilingualText()),
      streetLine: row['delivery_address'] as String? ?? '',
    );
  }
}
