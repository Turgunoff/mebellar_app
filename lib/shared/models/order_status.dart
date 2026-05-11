import 'package:flutter/material.dart';

/// Backend-aligned order lifecycle. Mobile UI groups these into 4 tabs
/// (active / new / completed / cancelled) — see `OrdersTab` in the BLoC.
enum OrderStatus {
  pending('pending'),
  confirmed('confirmed'),
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
  bool get cancellable =>
      this == OrderStatus.pending || this == OrderStatus.confirmed;

  IconData get icon => switch (this) {
        OrderStatus.pending => Icons.access_time,
        OrderStatus.confirmed => Icons.verified_outlined,
        OrderStatus.preparing => Icons.inventory_2_outlined,
        OrderStatus.shipped => Icons.local_shipping_outlined,
        OrderStatus.delivered => Icons.check_circle_outline,
        OrderStatus.cancelled => Icons.cancel_outlined,
      };
}
