import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/shared/models/chat.dart';
import 'package:woody_app/shared/repositories/woody_chat_repositories.dart';

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

Map<String, dynamic> _chat(String id) => {
      'id': id,
      'order_id': 'o1',
      'customer_id': 'cu1',
      'shop_id': 'sh1',
      'created_at': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> _msg(String id) => {
      'id': id,
      'chat_id': 'ch1',
      'sender_id': 'cu1',
      'sender_role': 'customer',
      'body': 'hi',
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

  ({WoodyChatRepository repo, _FakeAdapter adapter}) make(
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
    return (repo: WoodyChatRepository(api: api), adapter: adapter);
  }

  test('listMyChats maps the chat rows', () async {
    final h = make((_) => (200, jsonEncode([_chat('ch1')])));

    final chats = await h.repo.listMyChats();

    expect(chats.single.id, 'ch1');
    expect(chats.single.orderId, 'o1');
    expect(h.adapter.calls.single.uri.path, endsWith('/chats'));
  });

  test('openChatForOrder POSTs the order id and maps the chat', () async {
    final h = make((_) => (200, jsonEncode(_chat('ch1'))));

    final chat = await h.repo.openChatForOrder(orderId: 'o1');

    expect(chat.id, 'ch1');
    final call = h.adapter.calls.single;
    expect(call.method, 'POST');
    expect(call.uri.path, endsWith('/chats'));
    expect((call.data as Map)['order_id'], 'o1');
  });

  test('getChat finds the chat in the list', () async {
    final h = make((_) => (200, jsonEncode([_chat('ch1')])));
    expect((await h.repo.getChat('ch1')).id, 'ch1');
  });

  test('getChat throws when the chat is absent', () async {
    final h = make((_) => (200, jsonEncode([_chat('ch1')])));
    await expectLater(
      () => h.repo.getChat('missing'),
      throwsA(isA<StateError>()),
    );
  });

  test('listMessages hits the per-chat messages endpoint', () async {
    final h = make((_) => (200, jsonEncode([_msg('m1')])));

    final msgs = await h.repo.listMessages('ch1');

    expect(msgs.single.id, 'm1');
    expect(msgs.single.senderRole, ChatSenderRole.customer);
    expect(h.adapter.calls.single.uri.path, endsWith('/chats/ch1/messages'));
  });

  test('sendText POSTs the body and maps the returned message', () async {
    final h = make((_) => (200, jsonEncode(_msg('m1'))));

    final msg = await h.repo.sendText(
      chatId: 'ch1',
      body: 'salom',
      as: ChatSenderRole.customer,
    );

    expect(msg.id, 'm1');
    final call = h.adapter.calls.single;
    expect(call.method, 'POST');
    expect(call.uri.path, endsWith('/chats/ch1/messages'));
    expect((call.data as Map)['body'], 'salom');
  });

  test('markAsRead POSTs the read endpoint', () async {
    final h = make((_) => (200, '{}'));

    await h.repo.markAsRead('ch1');

    final call = h.adapter.calls.single;
    expect(call.method, 'POST');
    expect(call.uri.path, endsWith('/chats/ch1/read'));
  });
}
