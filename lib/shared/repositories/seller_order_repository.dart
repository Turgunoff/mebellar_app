import '../../core/result/result.dart';
import '../models/cancel_reason.dart';
import '../models/order.dart';
import '../models/order_status.dart';

/// Seller-side actions on an order. The customer-side `OrderRepository` only
/// supports cancel + watch; this one adds the workflow transitions sellers
/// drive (confirm → preparing → shipped → delivered) plus a stream of newly
/// inserted pending orders so the orders list can update without re-fetching.
///
/// ROADMAP B.1 — migrated to the `Result<T, Failure>` contract. The two
/// realtime feeds ([newOrders], [watch]) stay plain `Stream`s — a stream of
/// `Result` would conflate "the socket dropped" with "this order is bad data".
abstract class SellerOrderRepository {
  Future<Result<List<Order>>> list();
  Future<Result<Order>> getById(String id);

  /// Stream of newly pending orders for this seller's shop.
  Stream<Order> newOrders();

  /// Stream of UPDATEs on orders the seller can read — covers customer
  /// cancellations and status flips from another session so the orders
  /// list stays in sync without a manual refresh. Implementations that
  /// don't have a realtime channel (mocks, the remote stub) may return
  /// `const Stream.empty()`.
  Stream<Order> orderUpdates();

  /// State-machine transitions. Each enforces the legal source statuses on
  /// the backend; an illegal transition resolves to an [Err], not a throw.
  Future<Result<Order>> confirm(String id);
  Future<Result<Order>> markPreparing(String id);
  Future<Result<Order>> markShipped(String id);
  Future<Result<Order>> markDelivered(String id);

  /// Cancels [id] with a structured reason: a [reasonCode] from
  /// [fetchCancelReasons] plus free [reasonText] (required only when the code
  /// is `other`). A seller may cancel from any non-terminal state; an illegal
  /// transition resolves to an [Err], not a throw.
  Future<Result<Order>> cancel(
    String id, {
    required String reasonCode,
    String? reasonText,
  });

  /// Predefined seller cancellation reasons, localised by the active locale.
  /// Reference data — degrades to an empty list on failure (the picker then
  /// offers only the free-text path).
  Future<List<CancelReason>> fetchCancelReasons();

  /// Sets the order's delivery fee and re-derives the grand total. Allowed
  /// only while the order is still `pending`; once the seller accepts it the
  /// invoice is locked and the backend rejects the change (resolved to an
  /// [Err], not a throw). Returns the refreshed [Order] on success.
  Future<Result<Order>> setDeliveryFee(String id, {required num fee});

  Stream<Order> watch(String orderId);

  /// Releases realtime channels / stream controllers. Wired into the DI
  /// scope dispose callback.
  Future<void> dispose();
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
