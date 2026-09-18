import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/shared/repositories/payment_repository.dart';
import 'package:woody_app/shared/repositories/woody_seller_wallet_repository.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

const _json = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final (int, String) Function(RequestOptions options) responder;
  final List<RequestOptions> calls = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final (status, body) = responder(options);
    return ResponseBody.fromString(body, status, headers: _json);
  }
}

void main() {
  late TokenStore store;

  setUp(() async {
    final storage = _MockSecureStorage();
    final mem = <String, String>{};
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((i) async => mem[i.namedArguments[#key] as String]);
    when(
      () => storage.write(key: any(named: 'key'), value: any(named: 'value')),
    ).thenAnswer((i) async {
      mem[i.namedArguments[#key] as String] =
          i.namedArguments[#value] as String;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((i) async {
      mem.remove(i.namedArguments[#key] as String);
    });
    store = TokenStore(storage);
    await store.write(const TokenPair(accessToken: 'A', refreshToken: 'R'));
  });

  ({WoodySellerWalletRepository repo, _FakeAdapter adapter}) make(
    (int, String) Function(RequestOptions) responder,
  ) {
    final adapter = _FakeAdapter(responder);
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://test.local',
        validateStatus: (s) => s != null && s < 500,
      ),
    )..httpClientAdapter = adapter;
    return (
      repo: WoodySellerWalletRepository(api: WoodyApiClient(tokens: store, dio: dio)),
      adapter: adapter,
    );
  }

  test('fetch GETs /seller/wallet and returns Ok with the balance', () async {
    final h = make(
      (_) => (
        200,
        jsonEncode({
          'balance': -250000,
          'credit_limit': 1000000,
          'is_suspended_due_to_debt': false,
          'transactions': [
            {
              'id': 't1',
              'amount': -50000,
              'balance_after': -250000,
              'type': 'commission',
              'created_at': '2026-09-01T10:00:00Z',
            },
          ],
        }),
      ),
    );

    final result = await h.repo.fetch(recent: 30);

    expect(result.isOk, isTrue);
    expect(result.valueOrNull?.balance, -250000);
    expect(result.valueOrNull?.transactions.single.type, 'commission');
    expect(h.adapter.calls.single.uri.path, endsWith('/seller/wallet'));
    expect(h.adapter.calls.single.uri.queryParameters['recent'], '30');
  });

  test('createDeposit POSTs the amount + provider and returns the link',
      () async {
    final h = make(
      (_) => (
        200,
        jsonEncode({
          'provider': 'payme',
          'checkout_url': 'https://checkout.paycom.uz/abc',
          'amount': 250000,
          'reference': 'dep-1',
        }),
      ),
    );

    final result = await h.repo.createDeposit(
      amount: 250000,
      provider: PaymentProvider.payme,
    );

    expect(result.isOk, isTrue);
    expect(result.valueOrNull?.reference, 'dep-1');
    final call = h.adapter.calls.single;
    expect(call.method, 'POST');
    expect(call.uri.path, endsWith('/seller/wallet/deposit'));
    expect((call.data as Map)['amount'], 250000);
    expect((call.data as Map)['provider'], 'payme');
  });

  test('depositStatus returns Ok with the settled status', () async {
    final h = make((_) => (200, jsonEncode({'status': 'paid'})));

    final result = await h.repo.depositStatus('dep-1');

    expect(result.valueOrNull, 'paid');
    expect(
      h.adapter.calls.single.uri.path,
      endsWith('/seller/wallet/deposit/dep-1/status'),
    );
  });

  test(
    'depositStatus: a 200 with no status is Ok(pending), a 500 is Err '
    '— the poll must be able to tell them apart',
    () async {
      // The server answered; it simply has not settled yet. Keep polling.
      final answered = make((_) => (200, jsonEncode(<String, dynamic>{})));
      final okResult = await answered.repo.depositStatus('dep-1');
      expect(okResult.isOk, isTrue);
      expect(okResult.valueOrNull, 'pending');

      // We never reached the server. That is NOT "pending" — it is a failure,
      // and collapsing the two would let a backend outage read as a stuck
      // payment (or, worse, as a cancellation).
      final broken = make((_) => (500, '{"detail":"boom"}'));
      final errResult = await broken.repo.depositStatus('dep-1');
      expect(errResult.isOk, isFalse);
      expect(errResult.valueOrNull, isNull);
      expect(errResult.failureOrNull, isNotNull);
    },
  );

  test('submitManualTopup POSTs the receipt path and returns the row',
      () async {
    final h = make(
      (_) => (
        200,
        jsonEncode({
          'id': 'top-1',
          'amount': 500000,
          'status': 'pending',
          'submitted_at': '2026-09-01T10:00:00Z',
        }),
      ),
    );

    final result = await h.repo.submitManualTopup(
      amount: 500000,
      paymentScreenshotPath: 'receipts/abc.webp',
    );

    expect(result.valueOrNull?.id, 'top-1');
    expect(result.valueOrNull?.status, 'pending');
    expect(
      (h.adapter.calls.single.data as Map)['payment_screenshot_path'],
      'receipts/abc.webp',
    );
  });

  test('fetchTopUps maps the array and skips non-object rows', () async {
    final h = make(
      (_) => (
        200,
        jsonEncode([
          {
            'id': 'top-1',
            'amount': 500000,
            'status': 'approved',
            'submitted_at': '2026-09-01T10:00:00Z',
          },
          'garbage',
        ]),
      ),
    );

    final result = await h.repo.fetchTopUps();

    expect(result.valueOrNull, hasLength(1));
    expect(result.valueOrNull?.single.status, 'approved');
  });

  test('cancelTopUp PATCHes the row and returns Ok(void)', () async {
    final h = make((_) => (200, ''));

    final result = await h.repo.cancelTopUp('top-1');

    expect(result.isOk, isTrue);
    expect(h.adapter.calls.single.method, 'PATCH');
    expect(
      h.adapter.calls.single.uri.path,
      endsWith('/seller/wallet/topups/top-1/cancel'),
    );
  });

  test('cancelDeposit surfaces a backend refusal as Err, not a throw',
      () async {
    // Pre-T-10 this threw past the UI and the seller saw nothing at all.
    final h = make((_) => (409, '{"detail":"already_settled"}'));

    final result = await h.repo.cancelDeposit('dep-1');

    expect(result.isOk, isFalse);
    expect(result.failureOrNull, isNotNull);
    expect(result.failureOrNull?.message, isNotEmpty);
  });

  test('fetchTransactions passes limit + offset through', () async {
    final h = make((_) => (200, jsonEncode(<dynamic>[])));

    final result = await h.repo.fetchTransactions(limit: 25, offset: 50);

    expect(result.valueOrNull, isEmpty);
    final q = h.adapter.calls.single.uri.queryParameters;
    expect(q['limit'], '25');
    expect(q['offset'], '50');
  });

  test(
    'requestWithdrawal strips every non-digit from the card number',
    () async {
      // Money-routing data: the field is masked/spaced in the UI, and the
      // backend stores digits only. This has never had a test.
      final h = make(
        (_) => (
          200,
          jsonEncode({
            'id': 'w-1',
            'amount': 1000000,
            'card_number': '8600123412341234',
            'status': 'pending',
            'created_at': '2026-09-01T10:00:00Z',
          }),
        ),
      );

      final result = await h.repo.requestWithdrawal(
        amount: 1000000,
        cardNumber: '8600 1234-1234 1234',
      );

      expect(result.isOk, isTrue);
      expect(
        (h.adapter.calls.single.data as Map)['card_number'],
        '8600123412341234',
      );
    },
  );

  test('fetchWithdrawals omits the status query when it is null', () async {
    final h = make((_) => (200, jsonEncode(<dynamic>[])));

    await h.repo.fetchWithdrawals();
    expect(h.adapter.calls.single.uri.queryParameters, isEmpty);

    final filtered = make((_) => (200, jsonEncode(<dynamic>[])));
    await filtered.repo.fetchWithdrawals(status: 'pending');
    expect(
      filtered.adapter.calls.single.uri.queryParameters['status'],
      'pending',
    );
  });
}
