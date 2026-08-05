import '../models/address.dart';
import '../models/cancel_reason.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/shop.dart';

class CreateOrderInput {
  CreateOrderInput({
    required this.shop,
    required this.items,
    required this.address,
    required this.deliveryMethod,
    required this.paymentMethod,
    this.note,
  });

  final Shop shop;
  final List<CartItem> items;
  final Address address;
  final OrderDeliveryMethod deliveryMethod;
  final OrderPaymentMethod paymentMethod;
  final String? note;
}

abstract class OrderRepository {
  Future<List<Order>> list();

  /// First online order still awaiting payment, if any.
  Future<Order?> fetchAwaitingPaymentOrder();
  Future<Order> getById(String id);

  /// Single-shop order — one per shop group, so a multi-shop cart yields
  /// N orders. (The live checkout posts to `/orders` directly via
  /// `WoodyApiClient`; this typed path backs the repository contract.)
  Future<Order> create(CreateOrderInput input);

  /// Cancels [id] with a structured reason: a [reasonCode] from
  /// [fetchCancelReasons] plus free [reasonText] (required only when the code
  /// is `other`). The backend enforces customer cancel is pending-only.
  Future<Order> cancel(
    String id, {
    required String reasonCode,
    String? reasonText,
  });

  /// Predefined customer cancellation reasons, localised by the active locale
  /// (the API client stamps `Accept-Language`). The `other` code pairs with a
  /// free-text field in the picker.
  Future<List<CancelReason>> fetchCancelReasons();

  /// Customer accepts the seller's proposed delivery fee.
  /// Updates `total_amount`, clears the proposal columns.
  Future<Order> approveFeeAdjustment(String id);

  /// Customer rejects the seller's proposed delivery fee.
  /// Sets `fee_adjustment_status = 'rejected'`.
  Future<Order> rejectFeeAdjustment(String id);

  /// Stream that yields the latest version of [orderId] when the backend
  /// reports a status change. The mock variant simulates progression every
  /// few seconds; real impl will subscribe to a Woody realtime channel.
  Stream<Order> watch(String orderId);
}
