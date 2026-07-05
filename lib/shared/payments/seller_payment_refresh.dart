import 'dart:async';

import 'pending_payment.dart';

/// Broadcast hub so seller screens refresh after an online payment settles
/// (PaymentRecoveryGate) or the user returns from Payme/Click.
class SellerPaymentRefreshHub {
  SellerPaymentRefreshHub._();

  static final instance = SellerPaymentRefreshHub._();

  final _controller = StreamController<PendingPaymentKind>.broadcast();

  Stream<PendingPaymentKind> get stream => _controller.stream;

  void notify(PendingPaymentKind kind) {
    if (!_controller.isClosed) {
      _controller.add(kind);
    }
  }
}
