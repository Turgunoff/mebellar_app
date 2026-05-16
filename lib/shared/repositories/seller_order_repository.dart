import '../../core/error/failure.dart';
import '../../core/result/result.dart';
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

  /// State-machine transitions. Each enforces the legal source statuses on
  /// the backend; an illegal transition resolves to an [Err], not a throw.
  Future<Result<Order>> confirm(String id);
  Future<Result<Order>> markPreparing(String id);
  Future<Result<Order>> markShipped(String id);
  Future<Result<Order>> markDelivered(String id);
  Future<Result<Order>> cancel(String id, {required String reason});

  Stream<Order> watch(String orderId);

  /// Releases realtime channels / stream controllers. Wired into the DI
  /// scope dispose callback.
  Future<void> dispose();
}

/// Legacy Dio stub — superseded by `SupabaseSellerOrderRepository`. Kept so
/// the `RepositoryResolver` remote branch still resolves on non-Supabase
/// builds; every call returns an [Err].
class RemoteSellerOrderRepository implements SellerOrderRepository {
  RemoteSellerOrderRepository(this._dio);

  // ignore: unused_field — superseded by the Supabase implementation.
  final Object? _dio;

  static const Failure _unavailable = UnknownFailure(
    message: 'Remote seller orders — use the Supabase repository',
  );

  @override
  Future<Result<List<Order>>> list() async => const Err(_unavailable);

  @override
  Future<Result<Order>> getById(String id) async => const Err(_unavailable);

  @override
  Stream<Order> newOrders() => const Stream.empty();

  @override
  Future<Result<Order>> confirm(String id) async => const Err(_unavailable);

  @override
  Future<Result<Order>> markPreparing(String id) async =>
      const Err(_unavailable);

  @override
  Future<Result<Order>> markShipped(String id) async => const Err(_unavailable);

  @override
  Future<Result<Order>> markDelivered(String id) async =>
      const Err(_unavailable);

  @override
  Future<Result<Order>> cancel(String id, {required String reason}) async =>
      const Err(_unavailable);

  @override
  Stream<Order> watch(String orderId) => const Stream.empty();

  @override
  Future<void> dispose() async {}
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
