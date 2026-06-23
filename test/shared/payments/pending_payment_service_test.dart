import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woody_app/shared/payments/payment_status_gateway.dart';
import 'package:woody_app/shared/payments/pending_payment.dart';
import 'package:woody_app/shared/payments/pending_payment_service.dart';
import 'package:woody_app/shared/payments/pending_payment_store.dart';

/// Replays a scripted sequence of outcomes, one per `check` call (the last
/// entry repeats once exhausted), and counts how many probes were made.
class _FakeGateway implements PaymentStatusGateway {
  _FakeGateway(this._outcomes);

  final List<PaymentOutcome> _outcomes;
  int calls = 0;

  @override
  Future<PaymentOutcome> check(PendingPayment payment) async {
    final index = calls < _outcomes.length ? calls : _outcomes.length - 1;
    calls++;
    return _outcomes[index];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  PendingPaymentService service(List<PaymentOutcome> outcomes) =>
      PendingPaymentService(
        store: PendingPaymentStore(),
        gateway: _FakeGateway(outcomes),
      );

  const pending = PendingPayment(
    kind: PendingPaymentKind.order,
    reference: 'ord-1',
    createdAtMs: 0,
  );

  group('store round-trip', () {
    test('mark then peek returns the payment; clear removes it', () async {
      final s = service([PaymentOutcome.pending]);
      await s.mark(kind: PendingPaymentKind.order, reference: 'ord-1');

      final read = await s.peek();
      expect(read, isNotNull);
      expect(read!.kind, PendingPaymentKind.order);
      expect(read.reference, 'ord-1');

      await s.clear();
      expect(await s.peek(), isNull);
    });

    test('a new mark overwrites the previous one', () async {
      final s = service([PaymentOutcome.pending]);
      await s.mark(kind: PendingPaymentKind.order, reference: 'ord-1');
      await s.mark(kind: PendingPaymentKind.subscription, reference: 'rec-9');

      final read = await s.peek();
      expect(read!.kind, PendingPaymentKind.subscription);
      expect(read.reference, 'rec-9');
    });
  });

  group('pollUntilSettled', () {
    test('returns paid as soon as confirmed and stops early', () async {
      final gateway = _FakeGateway([
        PaymentOutcome.pending,
        PaymentOutcome.paid,
        PaymentOutcome.pending,
      ]);
      final s = PendingPaymentService(
        store: PendingPaymentStore(),
        gateway: gateway,
      );

      final outcome = await s.pollUntilSettled(
        pending,
        maxAttempts: 5,
        interval: Duration.zero,
      );

      expect(outcome, PaymentOutcome.paid);
      expect(gateway.calls, 2); // stopped at the second (paid) probe
    });

    test('returns the last outcome after the budget is exhausted', () async {
      final gateway = _FakeGateway([PaymentOutcome.pending]);
      final s = PendingPaymentService(
        store: PendingPaymentStore(),
        gateway: gateway,
      );

      final outcome = await s.pollUntilSettled(
        pending,
        maxAttempts: 3,
        interval: Duration.zero,
      );

      expect(outcome, PaymentOutcome.pending);
      expect(gateway.calls, 3);
    });

    test('unknown is never reported as paid', () async {
      final s = service([PaymentOutcome.unknown]);
      final outcome = await s.pollUntilSettled(
        pending,
        maxAttempts: 2,
        interval: Duration.zero,
      );
      expect(outcome, PaymentOutcome.unknown);
    });
  });

  test('checkOnce makes exactly one probe', () async {
    final gateway = _FakeGateway([PaymentOutcome.paid]);
    final s = PendingPaymentService(
      store: PendingPaymentStore(),
      gateway: gateway,
    );

    expect(await s.checkOnce(pending), PaymentOutcome.paid);
    expect(gateway.calls, 1);
  });
}
