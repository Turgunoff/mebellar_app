import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/shared/repositories/woody_shop_repository.dart';

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

  ({WoodyShopRepository repo, _FakeAdapter adapter}) makeRepo(
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
    return (repo: WoodyShopRepository(api: api), adapter: adapter);
  }

  test('shopById returns Ok with the mapped profile', () async {
    final h = makeRepo(
      (_) => (200, jsonEncode({'id': 'sh1', 'name': 'Mebel Shop'})),
    );

    final result = await h.repo.shopById('sh1');

    expect(result.isOk, isTrue);
    expect(result.valueOrNull?.id, 'sh1');
    expect(result.valueOrNull?.name, 'Mebel Shop');
    expect(h.adapter.calls.single.uri.path, endsWith('/catalog/shops/sh1'));
  });

  test('shopById surfaces a server error as Err', () async {
    final h = makeRepo((_) => (404, '{"detail":"not_found"}'));

    final result = await h.repo.shopById('missing');

    expect(result.isOk, isFalse);
    expect(result.valueOrNull, isNull);
  });

  test('productsByShop filters by shop_id and maps the rows', () async {
    final h = makeRepo(
      (_) => (
        200,
        jsonEncode({
          'rows': [
            {
              'id': 'p1',
              'category_id': 'c1',
              'name': 'Divan',
              'price': 100000,
              'created_at': '2026-01-01T00:00:00Z',
            },
          ],
        }),
      ),
    );

    final products = await h.repo.productsByShop('sh1');

    expect(products.single.id, 'p1');
    final call = h.adapter.calls.single;
    expect(call.uri.path, endsWith('/catalog/products'));
    expect(call.uri.queryParameters['shop_id'], 'sh1');
  });
}
