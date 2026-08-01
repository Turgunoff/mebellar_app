import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/shared/repositories/notifications_data_source.dart';

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

  ({WoodyNotificationDataSource ds, _FakeAdapter adapter}) make(
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
    return (ds: WoodyNotificationDataSource(api: api), adapter: adapter);
  }

  test('list maps the rows payload', () async {
    final h = make(
      (_) => (
        200,
        jsonEncode({
          'rows': [
            {
              'id': 'n1',
              'user_id': 'u1',
              'title': 'Salom',
              'is_read': false,
              'created_at': '2026-01-01T00:00:00Z',
            },
          ],
        }),
      ),
    );

    final items = await h.ds.list();

    expect(items.single.id, 'n1');
    expect(items.single.title, 'Salom');
    expect(items.single.isRead, isFalse);
    expect(h.adapter.calls.single.uri.path, endsWith('/notifications'));
  });

  test('unreadCount reads the unread_count field', () async {
    final h = make((_) => (200, '{"rows":[],"unread_count":5}'));
    expect(await h.ds.unreadCount(), 5);
  });

  test('guest session skips HTTP for list and unreadCount', () async {
    final storage = _MockSecureStorage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    final guestStore = TokenStore(storage);
    await guestStore.read(); // hydrate to null

    final adapter = _FakeAdapter((_) => (200, '{"rows":[],"unread_count":9}'));
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://test.local',
        validateStatus: (s) => s != null && s < 500,
      ),
    )..httpClientAdapter = adapter;
    final api = WoodyApiClient(tokens: guestStore, dio: dio);
    final ds = WoodyNotificationDataSource(api: api, tokens: guestStore);

    expect(await ds.list(), isEmpty);
    expect(await ds.unreadCount(), 0);
    expect(adapter.calls, isEmpty);
  });

  test('markRead PATCHes the per-id read endpoint', () async {
    final h = make((_) => (200, '{}'));

    await h.ds.markRead('n1');

    final call = h.adapter.calls.single;
    expect(call.method, 'PATCH');
    expect(call.uri.path, endsWith('/notifications/n1/read'));
  });

  test('markAllRead POSTs the mark-all-read endpoint', () async {
    final h = make((_) => (200, '{}'));

    await h.ds.markAllRead();

    final call = h.adapter.calls.single;
    expect(call.method, 'POST');
    expect(call.uri.path, endsWith('/notifications/mark-all-read'));
    // No mode → no audience query param (older-build behaviour).
    expect(call.uri.queryParameters.containsKey('mode'), isFalse);
  });

  test(
    'mode scopes the audience query param on list/unread/mark-all',
    () async {
      final list = make((_) => (200, '{"rows":[],"unread_count":0}'));
      await list.ds.list(mode: 'customer');
      expect(list.adapter.calls.single.uri.queryParameters['mode'], 'customer');

      final unread = make((_) => (200, '{"rows":[],"unread_count":2}'));
      await unread.ds.unreadCount(mode: 'seller');
      expect(unread.adapter.calls.single.uri.queryParameters['mode'], 'seller');

      final markAll = make((_) => (200, '{}'));
      await markAll.ds.markAllRead(mode: 'customer');
      final call = markAll.adapter.calls.single;
      expect(call.method, 'POST');
      expect(call.uri.queryParameters['mode'], 'customer');
    },
  );
}
