import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/network/mock_payme_client.dart';
import 'package:woody_app/core/network/payme_client.dart';

void main() {
  group('MockPaymeClient', () {
    // Duration.zero so the suite doesn't pay the simulated 1s latency.
    final client = MockPaymeClient(latency: Duration.zero);

    test('is a drop-in PaymeClient (so DI can swap it in)', () {
      expect(client, isA<PaymeClient>());
    });

    test('createCard returns a mock token + masked PAN', () async {
      final card = await client.createCard(
        number: '8600 1234 5678 1234',
        expire: '03/99',
      );
      expect(card.token, startsWith('mock_token_'));
      expect(card.maskedNumber, '8600 **** **** 1234');
      expect(card.verify, isFalse);
    });

    test('createCard issues a unique token per card', () async {
      final a = await client.createCard(
        number: '8600000000000001',
        expire: '0399',
      );
      final b = await client.createCard(
        number: '8600000000000002',
        expire: '0399',
      );
      expect(a.token, isNot(b.token));
    });

    test('getVerifyCode returns a challenge', () async {
      final challenge = await client.getVerifyCode('mock_token_x');
      expect(challenge.phone, isNotEmpty);
      expect(challenge.waitMs, greaterThan(0));
    });

    test(
      'verifyCard accepts any 6-digit code and echoes the masked number',
      () async {
        final created = await client.createCard(
          number: '8600123456781234',
          expire: '0399',
        );
        final verified = await client.verifyCard(
          token: created.token,
          code: '666666',
        );
        expect(verified.verify, isTrue);
        expect(verified.token, created.token);
        expect(verified.maskedNumber, '8600 **** **** 1234');
      },
    );

    test('verifyCard rejects a non-6-digit code', () async {
      await expectLater(
        () => client.verifyCard(token: 'mock_token_x', code: '123'),
        throwsA(isA<PaymeException>()),
      );
    });
  });
}
