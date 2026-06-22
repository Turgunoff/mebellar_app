import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/seller/features/products/data/ar_token_repository.dart';
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

  ({WoodyArTokenRepository repo, _FakeAdapter adapter}) make(
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
    return (repo: WoodyArTokenRepository(api: api), adapter: adapter);
  }

  test('balance parses ar_credits + packages', () async {
    final h = make(
      (_) => (
        200,
        jsonEncode({
          'ar_credits': 4,
          'packages': [
            {'code': 'single', 'tokens': 1, 'price_uzs': 15000},
            {'code': 'pack5', 'tokens': 5, 'price_uzs': 60000},
          ],
        }),
      ),
    );

    final balance = await h.repo.balance();

    expect(balance.arCredits, 4);
    expect(balance.packages, hasLength(2));
    expect(balance.packages[1].code, 'pack5');
    expect(balance.packages[1].tokens, 5);
    expect(balance.packages[1].priceUzs, 60000);
    expect(h.adapter.calls.single.uri.path, endsWith('/seller/ar-tokens/balance'));
  });

  test('buy posts package_code + provider and returns the checkout url', () async {
    final h = make(
      (_) => (
        200,
        jsonEncode({
          'provider': 'payme',
          'checkout_url': 'https://checkout.paycom.uz/abc',
          'amount': 45000,
        }),
      ),
    );

    final url = await h.repo.buy(
      packageCode: 'pack5',
      provider: PaymentProvider.payme,
    );

    expect(url, 'https://checkout.paycom.uz/abc');
    final call = h.adapter.calls.single;
    expect(call.method, 'POST');
    expect(call.uri.path, endsWith('/seller/ar-tokens/buy'));
    expect(call.data, {'package_code': 'pack5', 'provider': 'payme'});
  });
}
