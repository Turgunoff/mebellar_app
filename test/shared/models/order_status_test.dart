import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/models/order_status.dart';

void main() {
  test('fromCode maps known codes and defaults to pending', () {
    expect(OrderStatus.fromCode('shipped'), OrderStatus.shipped);
    expect(OrderStatus.fromCode('nope'), OrderStatus.pending);
    expect(OrderStatus.fromCode(null), OrderStatus.pending);
  });

  test('isTerminal / isActive', () {
    expect(OrderStatus.delivered.isTerminal, isTrue);
    expect(OrderStatus.cancelled.isTerminal, isTrue);
    expect(OrderStatus.pending.isTerminal, isFalse);
    expect(OrderStatus.shipped.isActive, isTrue);
  });

  test('customerCancellable is pending-only', () {
    expect(OrderStatus.pending.customerCancellable, isTrue);
    for (final s in const [
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.shipped,
      OrderStatus.delivered,
      OrderStatus.cancelled,
    ]) {
      expect(
        s.customerCancellable,
        isFalse,
        reason: '$s not customer-cancellable',
      );
    }
  });

  test('sellerCancellable is every non-terminal state', () {
    for (final s in const [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.shipped,
    ]) {
      expect(
        s.sellerCancellable,
        isTrue,
        reason: '$s should be seller-cancellable',
      );
    }
    expect(OrderStatus.delivered.sellerCancellable, isFalse);
    expect(OrderStatus.cancelled.sellerCancellable, isFalse);
  });
}
