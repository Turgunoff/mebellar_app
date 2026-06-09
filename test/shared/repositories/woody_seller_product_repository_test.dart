import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/shared/repositories/woody_seller_product_repository.dart';

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

Map<String, dynamic> _row(String id, {String status = 'approved'}) => {
      'id': id,
      'name': 'Divan',
      'price': 100000,
      'status': status,
      'sku': 'SKU1',
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

  ({WoodySellerProductRepository repo, _FakeAdapter adapter}) make(
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
    return (repo: WoodySellerProductRepository(api: api), adapter: adapter);
  }

  test('list maps rows into a Paginated page with limit/offset query',
      () async {
    final h = make(
      (_) => (200, jsonEncode({'rows': [_row('sp1')], 'total': 1})),
    );

    final page = await h.repo.list();

    expect(page.items.single.id, 'sp1');
    expect(page.items.single.name.uz, 'Divan');
    expect(page.total, 1);
    expect(page.page, 1);
    expect(page.hasNext, isFalse);
    final call = h.adapter.calls.single;
    expect(call.uri.path, endsWith('/seller/products'));
    expect(call.uri.queryParameters['limit'], '20');
    expect(call.uri.queryParameters['offset'], '0');
  });

  test('archive POSTs the archive endpoint and maps the product', () async {
    final h = make((opts) {
      if (opts.uri.path.endsWith('/archive')) {
        return (200, jsonEncode(_row('sp1', status: 'archived')));
      }
      return (200, '{}');
    });

    final p = await h.repo.archive('sp1');

    expect(p.id, 'sp1');
    final call = h.adapter.calls.single;
    expect(call.method, 'POST');
    expect(call.uri.path, endsWith('/seller/products/sp1/archive'));
  });

  test('restore POSTs the restore endpoint', () async {
    final h = make((opts) {
      if (opts.uri.path.endsWith('/restore')) {
        return (200, jsonEncode(_row('sp1')));
      }
      return (200, '{}');
    });

    final p = await h.repo.restore('sp1');

    expect(p.id, 'sp1');
    final call = h.adapter.calls.single;
    expect(call.method, 'POST');
    expect(call.uri.path, endsWith('/seller/products/sp1/restore'));
  });
}
