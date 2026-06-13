import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/shared/models/order_status.dart';
import 'package:woody_app/shared/repositories/woody_customer_repositories.dart';

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

// A woody_backend order row. total_amount (250000) exceeds the line total
// (100000 × 2), so the mapper infers a 50000 delivery fee.
Map<String, dynamic> _orderRow({
  String status = 'pending',
  String? cancelReason,
}) => {
  'id': 'abcd1234-aaaa-bbbb-cccc',
  'status': status,
  'created_at': '2026-01-01T00:00:00Z',
  'total_amount': 250000,
  'delivery_address': 'Toshkent, Chilonzor',
  if (cancelReason != null) 'cancellation_reason': cancelReason,
  'items': [
    {
      'id': 'i1',
      'product_id': 'p1',
      'price': 100000,
      'quantity': 2,
      'product': {
        'name': 'Divan',
        'images': ['a.jpg'],
      },
    },
  ],
};

void main() {
  late _MockSecureStorage storage;
  late TokenStore store;

  setUp(() async {
    storage = _MockSecureStorage();
    final mem = <String, String>{};
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((i) async => mem[i.namedArguments[#key] as String]);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
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

  ({WoodyOrderRepository repo, _FakeAdapter adapter}) makeRepo(
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
    return (repo: WoodyOrderRepository(api), adapter: adapter);
  }

  test('list maps rows and derives order number, totals and fee', () async {
    final h = makeRepo(
      (_) => (
        200,
        jsonEncode({
          'rows': [_orderRow()],
        }),
      ),
    );

    final orders = await h.repo.list();

    expect(orders, hasLength(1));
    final o = orders.single;
    expect(o.id, 'abcd1234-aaaa-bbbb-cccc');
    expect(o.orderNumber, 'WD-ABCD1234'); // 'WD-' + first 8 of id, upper
    expect(o.status, OrderStatus.pending);
    expect(o.itemsTotal, 200000);
    expect(o.deliveryFee, 50000); // total_amount - itemsTotal
    expect(o.grandTotal, 250000);
    expect(o.items.single.quantity, 2);
    expect(o.items.single.lineTotal, 200000);
    expect(o.items.single.productName.uz, 'Divan');
  });

  test('list returns empty when the payload carries no rows', () async {
    final h = makeRepo((_) => (200, '{}'));
    expect(await h.repo.list(), isEmpty);

    final h2 = makeRepo((_) => (200, '{"rows":[]}'));
    expect(await h2.repo.list(), isEmpty);
  });

  test('getById maps a single order', () async {
    final h = makeRepo((_) => (200, jsonEncode(_orderRow(status: 'shipped'))));

    final o = await h.repo.getById('abcd1234-aaaa-bbbb-cccc');

    expect(o.status, OrderStatus.shipped);
    expect(o.orderNumber, 'WD-ABCD1234');
    expect(
      h.adapter.calls.single.uri.path,
      endsWith('/orders/abcd1234-aaaa-bbbb-cccc'),
    );
  });

  test('cancel posts the reason and maps the cancelled order', () async {
    final h = makeRepo((opts) {
      if (opts.uri.path.endsWith('/cancel')) {
        return (
          200,
          jsonEncode(
            _orderRow(status: 'cancelled', cancelReason: 'no longer needed'),
          ),
        );
      }
      return (200, '{}');
    });

    final o = await h.repo.cancel(
      'abcd1234-aaaa-bbbb-cccc',
      reasonCode: 'other',
      reasonText: 'no longer needed',
    );

    expect(o.status, OrderStatus.cancelled);
    expect(o.cancelReason, 'no longer needed');
    final call = h.adapter.calls.single;
    expect(call.method, 'POST');
    expect(call.uri.path, endsWith('/orders/abcd1234-aaaa-bbbb-cccc/cancel'));
    expect((call.data as Map)['cancel_reason_code'], 'other');
    expect((call.data as Map)['cancel_reason_text'], 'no longer needed');
  });
}
