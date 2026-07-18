import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/shared/repositories/checkout_repository.dart';

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

  ({WoodyCheckoutRepository repo, _FakeAdapter adapter}) make(
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
    return (repo: WoodyCheckoutRepository(api), adapter: adapter);
  }

  const line = CheckoutOrderLine(productId: 'p1', quantity: 2);

  test('quote POSTs to /orders/quote and returns Ok with the invoice', () async {
    final h = make(
      (_) => (
        200,
        jsonEncode({
          'subtotal': 1000000,
          'delivery_fee': 300000,
          'installation_fee': 500000,
          'installation_available': true,
          'grand_total': 1300000,
        }),
      ),
    );

    final result = await h.repo.quote(
      lines: const [line],
      deliveryAddress: 'Tashkent',
      wantInstallation: false,
    );

    expect(result.isOk, isTrue);
    expect(result.valueOrNull?.deliveryFee, 300000);
    expect(result.valueOrNull?.installationAvailable, isTrue);
    expect(h.adapter.calls.single.uri.path, endsWith('/orders/quote'));
  });

  test('placeOrder POSTs to /orders and returns Ok with the new order id',
      () async {
    final h = make((_) => (200, jsonEncode({'id': 'order-42'})));

    final result = await h.repo.placeOrder(
      lines: const [line],
      deliveryAddress: 'Tashkent',
      paymentMethod: 'payme',
    );

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, 'order-42');
    expect(h.adapter.calls.single.method, 'POST');
    expect(h.adapter.calls.single.uri.path, endsWith('/orders'));
  });

  test('placeOrder surfaces a backend error as Err, not a throw', () async {
    final h = make((_) => (422, '{"detail":"multi_shop_cart_not_supported"}'));

    final result = await h.repo.placeOrder(
      lines: const [line],
      deliveryAddress: 'Tashkent',
    );

    expect(result.isOk, isFalse);
    expect(result.valueOrNull, isNull);
    expect(result.failureOrNull, isNotNull);
  });
}
