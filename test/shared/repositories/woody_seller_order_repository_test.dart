import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/shared/models/order_status.dart';
import 'package:woody_app/shared/repositories/woody_seller_order_repository.dart';

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

Map<String, dynamic> _order(String id, {String status = 'pending'}) => {
      'id': id,
      'status': status,
      'total_amount': 100000,
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

  ({WoodySellerOrderRepository repo, _FakeAdapter adapter}) make(
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
    return (repo: WoodySellerOrderRepository(api: api), adapter: adapter);
  }

  test('list returns Ok with the mapped seller orders', () async {
    final h = make(
      (_) => (200, jsonEncode({'rows': [_order('o1')]})),
    );

    final result = await h.repo.list();

    expect(result.isOk, isTrue);
    expect(result.valueOrNull?.single.id, 'o1');
    expect(h.adapter.calls.single.uri.path, endsWith('/seller/orders'));
  });

  test('list surfaces a server error as Err', () async {
    final h = make((_) => (500, '{"detail":"boom"}'));
    expect((await h.repo.list()).isOk, isFalse);
  });

  test('confirm PATCHes the status endpoint with confirmed', () async {
    final h = make(
      (_) => (200, jsonEncode(_order('o1', status: 'confirmed'))),
    );

    final result = await h.repo.confirm('o1');

    expect(result.isOk, isTrue);
    expect(result.valueOrNull?.status, OrderStatus.confirmed);
    final call = h.adapter.calls.single;
    expect(call.method, 'PATCH');
    expect(call.uri.path, endsWith('/seller/orders/o1/status'));
    expect((call.data as Map)['status'], 'confirmed');
  });

  test('cancel sends the reason alongside the cancelled status', () async {
    final h = make(
      (_) => (
        200,
        jsonEncode(_order('o1', status: 'cancelled')),
      ),
    );

    final result = await h.repo.cancel('o1', reason: 'out of stock');

    expect(result.isOk, isTrue);
    final body = h.adapter.calls.single.data as Map;
    expect(body['status'], 'cancelled');
    expect(body['cancellation_reason'], 'out of stock');
  });
}
