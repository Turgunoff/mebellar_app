import '../../core/network/woody_api_client.dart';
import '../../core/result/result.dart';
import '../models/address.dart';
import '../models/cancel_reason.dart';
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
  Future<Result<Order>> cancel(
    String id, {
    required String reasonCode,
    String? reasonText,
  }) => _transition(
    id,
    OrderStatus.cancelled,
    reasonCode: reasonCode,
    reasonText: reasonText,
  );

  @override
  Future<List<CancelReason>> fetchCancelReasons() async {
    try {
      final rows = await _api.get<List<dynamic>>(
        '/orders/cancel-reasons',
        query: const {'role': 'seller'},
        retries: 2,
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map(CancelReason.fromJson)
          .toList(growable: false);
    } on Object {
      // Reference data — degrade to an empty list so the picker still offers
      // the free-text path instead of blocking the cancel.
      return const <CancelReason>[];
    }
  }

  /// `PATCH /seller/orders/{id}/status` with a [SetOrderStatusBody] payload.
  /// The backend enforces the legal transition table (state machine in
  /// `order_policy.py`); an illegal transition or a missing order resolves to
  /// an [Err] via [runCatching]. On cancel it carries the structured
  /// `cancel_reason_code` + `cancel_reason_text`. The endpoint returns the
  /// refreshed [SellerOrder], so no re-read is needed.
  Future<Result<Order>> _transition(
    String id,
    OrderStatus next, {
    String? reasonCode,
    String? reasonText,
  }) => runCatching(() async {
    final row = await _api.patch<Map<String, dynamic>>(
      '$_ordersPath/$id/status',
      body: {
        'status': next.code,
        'cancel_reason_code': ?reasonCode,
        if (reasonText != null && reasonText.isNotEmpty)
          'cancel_reason_text': reasonText,
      },
    );
    return _toOrder(row);
  });

  /// `PATCH /seller/orders/{id}/delivery-fee` with a `{delivery_fee}` payload.
  /// The backend sets the fee, re-derives `total_amount`, and returns the
  /// refreshed [SellerOrder]. It rejects the change (→ [Err]) when the order
  /// is no longer `pending` — the invoice is locked once accepted.
  @override
  Future<Result<Order>> setDeliveryFee(String id, {required num fee}) =>
      runCatching(() async {
        final row = await _api.patch<Map<String, dynamic>>(
          '$_ordersPath/$id/delivery-fee',
          body: {'delivery_fee': fee},
        );
        return _toOrder(row);
      });

  /// `POST /seller/orders/{id}/accept` with `{delivery_fee}`. The backend stamps
  /// the exact fee, re-derives `total_amount`, and branches the status (cash →
  /// confirmed, online → awaiting_payment), returning the refreshed order. A
  /// non-pending order resolves to an [Err] (409).
  @override
  Future<Result<Order>> accept(String id, {required int deliveryFee}) =>
      runCatching(() async {
        final row = await _api.post<Map<String, dynamic>>(
          '$_ordersPath/$id/accept',
          body: {'delivery_fee': deliveryFee},
        );
        return _toOrder(row);
      });

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
  ///
  /// The backend shape differs from the customer order row (`subtotal` vs
  /// `items_total`, `installation_fee` vs `services_fee`, `payment_provider`
  /// without `payment_method`), so we normalise before [Order.fromJson].
  Order _toOrder(Map<String, dynamic> row) {
    final id = row['id'] as String? ?? '';
    final itemsRaw = (row['items'] as List<dynamic>?) ?? const [];
    final items = itemsRaw
        .whereType<Map<String, dynamic>>()
        .map(_toOrderItem)
        .toList(growable: false);
    final itemsSum = items.fold<num>(0, (sum, it) => sum + it.lineTotal);
    final paymentProvider = row['payment_provider'] as String? ?? 'cash';
    final normalized = Map<String, dynamic>.from(row)
      ..['items_total'] = (row['subtotal'] as num?) ?? itemsSum
      ..['services_fee'] = row['installation_fee'] ?? 0
      ..['delivery_method'] = 'delivery'
      ..['payment_method'] = paymentProvider == 'cash'
          ? 'cash_on_delivery'
          : 'card';
    return Order.fromJson(
      normalized,
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
      lat: (row['delivery_latitude'] as num?)?.toDouble(),
      lng: (row['delivery_longitude'] as num?)?.toDouble(),
    );
  }
}
