import 'package:flutter/material.dart';

/// Backend-aligned order lifecycle. Mobile UI groups these into 4 tabs
/// (active / new / completed / cancelled) — see `OrdersTab` in the BLoC.
enum OrderStatus {
  pending('pending'),
  confirmed('confirmed'),
  // Deferred payment: an online (payme/click) order the seller accepted lands
  // here instead of `confirmed`. The customer pays the final (item + delivery)
  // total from the order screen; the payment webhook then advances it forward.
  awaitingPayment('awaiting_payment'),
  preparing('preparing'),
  shipped('shipped'),
  delivered('delivered'),
  cancelled('cancelled');

  const OrderStatus(this.code);
  final String code;

  static OrderStatus fromCode(String? code) {
    return OrderStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => OrderStatus.pending,
    );
  }

  bool get isTerminal =>
      this == OrderStatus.delivered || this == OrderStatus.cancelled;
  bool get isActive => !isTerminal;

  /// The customer still owes payment — drives the "To'lovni amalga oshirish"
  /// button on the order screen.
  bool get awaitsPayment => this == OrderStatus.awaitingPayment;

  /// A customer may self-cancel ONLY while the order is still `pending` — once
  /// the seller confirms, cancellation is the seller's call (protects seller
  /// logistics costs). Mirrors the backend state machine in `order_policy.py`.
  bool get customerCancellable => this == OrderStatus.pending;

  /// A seller may cancel/reject from any non-terminal state (e.g. the customer
  /// is unreachable or logistics fail).
  bool get sellerCancellable => isActive;

  IconData get icon => switch (this) {
    OrderStatus.pending => Icons.access_time,
    OrderStatus.confirmed => Icons.verified_outlined,
    OrderStatus.awaitingPayment => Icons.payments_outlined,
    OrderStatus.preparing => Icons.inventory_2_outlined,
    OrderStatus.shipped => Icons.local_shipping_outlined,
    OrderStatus.delivered => Icons.check_circle_outline,
    OrderStatus.cancelled => Icons.cancel_outlined,
  };
}
