import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/models/seller_wallet.dart';

void main() {
  group('SellerWallet.fromJson', () {
    test('parses the full backend payload', () {
      final wallet = SellerWallet.fromJson({
        'balance': -672000,
        'credit_limit': 500000,
        'debt_floor': -500000,
        'is_suspended_due_to_debt': false,
        'debt_grace_period_until': '2026-06-13T10:00:00+00:00',
        'pending_topup': {
          'id': 'b1c2d3',
          'amount': 300000,
          'status': 'pending',
          'submitted_at': '2026-06-11T09:00:00+00:00',
        },
        'transactions': [
          {
            'id': 'tx-1',
            'amount': -72000,
            'balance_after': -672000,
            'type': 'commission',
            'note': "Buyurtma komissiyasi — 72 000 so'm",
            'created_at': '2026-06-11T08:00:00+00:00',
          },
        ],
      });

      expect(wallet.balance, -672000);
      expect(wallet.creditLimit, 500000);
      expect(wallet.debtFloor, -500000);
      expect(wallet.isSuspendedDueToDebt, isFalse);
      expect(wallet.isInGrace, isTrue);
      expect(wallet.debtAmount, 172000);
      expect(wallet.pendingTopUp?.amount, 300000);
      expect(wallet.pendingTopUp?.isPending, isTrue);
      expect(wallet.transactions, hasLength(1));
      expect(wallet.transactions.first.isDebit, isTrue);
      expect(wallet.transactions.first.typeLabel, 'Komissiya');
    });

    test('defaults to a healthy zero wallet on an empty payload', () {
      final wallet = SellerWallet.fromJson(const {});
      expect(wallet.balance, 0);
      expect(wallet.isHealthy, isTrue);
      expect(wallet.isInGrace, isFalse);
      expect(wallet.debtAmount, 0);
      expect(wallet.pendingTopUp, isNull);
      expect(wallet.transactions, isEmpty);
    });

    test('suspended wallet is not "in grace" even with a deadline set', () {
      final wallet = SellerWallet.fromJson({
        'balance': -700000,
        'credit_limit': 500000,
        'debt_floor': -500000,
        'is_suspended_due_to_debt': true,
        'debt_grace_period_until': '2026-06-10T10:00:00+00:00',
      });
      expect(wallet.isSuspendedDueToDebt, isTrue);
      expect(wallet.isInGrace, isFalse);
      expect(wallet.debtAmount, 200000);
    });
  });

  group('graceHoursLeft', () {
    test('floors at 1 so the banner never shows a dead "0 soat"', () {
      final wallet = SellerWallet(
        balance: -600000,
        creditLimit: 500000,
        debtFloor: -500000,
        graceUntil: DateTime.utc(2026, 6, 13, 10),
      );
      expect(
        wallet.graceHoursLeft(DateTime.utc(2026, 6, 13, 9, 59)),
        1,
      );
      expect(
        wallet.graceHoursLeft(DateTime.utc(2026, 6, 12, 10)),
        24,
      );
    });
  });

  group('formatSom', () {
    test('groups thousands with spaces and keeps the sign', () {
      expect(formatSom(0), '0');
      expect(formatSom(950), '950');
      expect(formatSom(1234567), '1 234 567');
      expect(formatSom(-500000), '-500 000');
    });
  });
}
