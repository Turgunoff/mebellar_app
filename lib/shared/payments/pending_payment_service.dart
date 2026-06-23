import 'dart:async';

import 'payment_status_gateway.dart';
import 'pending_payment.dart';
import 'pending_payment_store.dart';

/// Orchestrates the in-flight external-payment lifecycle: [mark] a payment the
/// instant the app hands off to Payme/Click, then reconcile it when the
/// customer returns — [pollUntilSettled] on resume (the app merely
/// backgrounded) or [checkOnce] on cold start (the OS killed the app
/// mid-payment). Root-scoped so both customer and seller modes share it.
class PendingPaymentService {
  PendingPaymentService({
    required PendingPaymentStore store,
    required PaymentStatusGateway gateway,
  }) : _store = store,
       _gateway = gateway;

  final PendingPaymentStore _store;
  final PaymentStatusGateway _gateway;

  /// Resume-poll budget: 5 attempts, 3s apart ≈ 15s. The first check waits one
  /// interval so the provider webhook has a moment to land before we probe.
  static const defaultMaxAttempts = 5;
  static const defaultInterval = Duration(seconds: 3);

  /// Records a payment as in-flight before launching the provider deep-link.
  Future<void> mark({
    required PendingPaymentKind kind,
    required String reference,
  }) {
    return _store.save(
      PendingPayment(
        kind: kind,
        reference: reference,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// The marker currently in flight, or null. Reading never clears it — the
  /// caller [clear]s explicitly once it has shown the user the outcome.
  Future<PendingPayment?> peek() => _store.read();

  Future<void> clear() => _store.clear();

  /// A single status probe — cold-start recovery, where there's no time budget
  /// to spend (the app just launched and we only confirm what already settled).
  Future<PaymentOutcome> checkOnce(PendingPayment payment) =>
      _gateway.check(payment);

  /// Polls until the payment settles or the budget is exhausted. Returns `paid`
  /// the instant it confirms; otherwise the last observed outcome
  /// (`pending`/`unknown`) after the window closes.
  Future<PaymentOutcome> pollUntilSettled(
    PendingPayment payment, {
    int maxAttempts = defaultMaxAttempts,
    Duration interval = defaultInterval,
  }) async {
    var last = PaymentOutcome.pending;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future<void>.delayed(interval);
      final outcome = await _gateway.check(payment);
      if (outcome == PaymentOutcome.paid) return PaymentOutcome.paid;
      last = outcome;
    }
    return last;
  }
}
