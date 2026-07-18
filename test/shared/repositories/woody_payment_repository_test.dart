import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/shared/repositories/payment_repository.dart';

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

  ({WoodyPaymentRepository repo, _FakeAdapter adapter}) make(
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
    return (repo: WoodyPaymentRepository(api: api), adapter: adapter);
  }

  test('checkoutUrl POSTs to /orders/{id}/pay/{provider} and returns Ok',
      () async {
    final h = make(
      (_) => (
        200,
        jsonEncode({
          'provider': 'payme',
          'checkout_url': 'https://checkout.paycom.uz/abc',
          'amount': 299000,
          'reference': 'order-7',
        }),
      ),
    );

    final result = await h.repo.checkoutUrl(
      orderId: 'order-7',
      provider: PaymentProvider.payme,
    );

    expect(result.isOk, isTrue);
    expect(result.valueOrNull?.checkoutUrl, 'https://checkout.paycom.uz/abc');
    expect(result.valueOrNull?.amount, 299000);
    expect(result.valueOrNull?.reference, 'order-7');
    expect(h.adapter.calls.single.method, 'POST');
    expect(
      h.adapter.calls.single.uri.path,
      endsWith('/orders/order-7/pay/payme'),
    );
  });

  test('checkoutUrl surfaces a 409 (already paid) as Err, not a throw',
      () async {
    final h = make((_) => (409, '{"detail":"already_paid"}'));

    final result = await h.repo.checkoutUrl(
      orderId: 'order-7',
      provider: PaymentProvider.click,
    );

    expect(result.isOk, isFalse);
    expect(result.valueOrNull, isNull);
    expect(result.failureOrNull, isNotNull);
  });
}
