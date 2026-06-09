import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/shared/repositories/woody_product_repository.dart';

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

Map<String, dynamic> _product(String id) => {
      'id': id,
      'category_id': 'c1',
      'name': 'Divan',
      'price': 100000,
      'created_at': '2026-01-01T00:00:00Z',
    };

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

  ({WoodyProductRepository repo, _FakeAdapter adapter}) makeRepo(
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
    return (repo: WoodyProductRepository(api: api), adapter: adapter);
  }

  test('getById maps a single product', () async {
    final h = makeRepo((_) => (200, jsonEncode(_product('p1'))));

    final p = await h.repo.getById('p1');

    expect(p.id, 'p1');
    expect(p.name, 'Divan');
    expect(p.price, 100000.0);
    expect(h.adapter.calls.single.uri.path, endsWith('/catalog/products/p1'));
  });

  test('search short-circuits an empty default query without hitting the API',
      () async {
    final h = makeRepo((_) => (200, '{"rows":[]}'));

    expect(await h.repo.search(''), isEmpty);
    expect(h.adapter.calls, isEmpty);
  });

  test('search sends the term as a query param and maps the rows', () async {
    final h = makeRepo((_) => (200, jsonEncode({'rows': [_product('p1')]})));

    final res = await h.repo.search('divan');

    expect(res.single.id, 'p1');
    final call = h.adapter.calls.single;
    expect(call.uri.path, endsWith('/catalog/products'));
    expect(call.uri.queryParameters['search'], 'divan');
  });

  test('listSimilar hits the similar endpoint and maps the list', () async {
    final h = makeRepo((_) => (200, jsonEncode([_product('p2')])));

    final res = await h.repo.listSimilar('p1');

    expect(res.single.id, 'p2');
    expect(h.adapter.calls.single.uri.path,
        endsWith('/catalog/products/p1/similar'));
  });
}
