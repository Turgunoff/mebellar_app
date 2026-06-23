import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/shared/payments/payment_status_gateway.dart';
import 'package:woody_app/shared/payments/pending_payment.dart';

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
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((i) async => mem[i.namedArguments[#key] as String]);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((i) async {
      mem[i.namedArguments[#key] as String] =
          i.namedArguments[#value] as String;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((i) async {
      mem.remove(i.namedArguments[#key] as String);
    });
    store = TokenStore(storage);
    await store.write(const TokenPair(accessToken: 'A', refreshToken: 'R'));
  });

  ({WoodyPaymentStatusGateway gateway, _FakeAdapter adapter}) make(
    (int, String) Function(RequestOptions) responder,
  ) {
    final adapter = _FakeAdapter(responder);
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://test.local',
        validateStatus: (s) => s != null && s < 500,
      ),
    )..httpClientAdapter = adapter;
    final api = WoodyApiClient(tokens: store, dio: dio);
    return (gateway: WoodyPaymentStatusGateway(api: api), adapter: adapter);
  }

  group('order', () {
    test('payment_status "paid" → paid, hitting /orders/{id}', () async {
      final h = make((_) => (200, jsonEncode({'payment_status': 'paid'})));
      final outcome = await h.gateway.check(
        const PendingPayment(
          kind: PendingPaymentKind.order,
          reference: 'ord-7',
          createdAtMs: 0,
        ),
      );
      expect(outcome, PaymentOutcome.paid);
      expect(h.adapter.calls.single.uri.path, endsWith('/orders/ord-7'));
    });

    test('payment_status "unpaid" → pending', () async {
      final h = make((_) => (200, jsonEncode({'payment_status': 'unpaid'})));
      final outcome = await h.gateway.check(
        const PendingPayment(
          kind: PendingPaymentKind.order,
          reference: 'ord-7',
          createdAtMs: 0,
        ),
      );
      expect(outcome, PaymentOutcome.pending);
    });
  });

  group('ar tokens', () {
    test('paid:true → paid, hitting the purchases endpoint', () async {
      final h = make((_) => (200, jsonEncode({'status': 'paid', 'paid': true})));
      final outcome = await h.gateway.check(
        const PendingPayment(
          kind: PendingPaymentKind.arTokens,
          reference: 'pur-3',
          createdAtMs: 0,
        ),
      );
      expect(outcome, PaymentOutcome.paid);
      expect(
        h.adapter.calls.single.uri.path,
        endsWith('/seller/ar-tokens/purchases/pur-3'),
      );
    });

    test('paid:false → pending', () async {
      final h =
          make((_) => (200, jsonEncode({'status': 'pending', 'paid': false})));
      final outcome = await h.gateway.check(
        const PendingPayment(
          kind: PendingPaymentKind.arTokens,
          reference: 'pur-3',
          createdAtMs: 0,
        ),
      );
      expect(outcome, PaymentOutcome.pending);
    });
  });

  group('subscription', () {
    test('paid:true → paid, hitting the receipt-status endpoint', () async {
      final h =
          make((_) => (200, jsonEncode({'status': 'approved', 'paid': true})));
      final outcome = await h.gateway.check(
        const PendingPayment(
          kind: PendingPaymentKind.subscription,
          reference: 'rec-5',
          createdAtMs: 0,
        ),
      );
      expect(outcome, PaymentOutcome.paid);
      expect(
        h.adapter.calls.single.uri.path,
        endsWith('/seller/tariff/receipts/rec-5/status'),
      );
    });
  });

  test('a server/network error resolves to unknown (never paid)', () async {
    final h = make((_) => (500, '{}'));
    final outcome = await h.gateway.check(
      const PendingPayment(
        kind: PendingPaymentKind.order,
        reference: 'ord-7',
        createdAtMs: 0,
      ),
    );
    expect(outcome, PaymentOutcome.unknown);
  });

  test('a 404 (not the caller\'s payment) resolves to unknown', () async {
    final h = make((_) => (404, jsonEncode({'detail': 'not_found'})));
    final outcome = await h.gateway.check(
      const PendingPayment(
        kind: PendingPaymentKind.arTokens,
        reference: 'pur-3',
        createdAtMs: 0,
      ),
    );
    expect(outcome, PaymentOutcome.unknown);
  });
}
