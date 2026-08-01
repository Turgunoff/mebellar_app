import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/core/realtime/woody_realtime_service.dart';
import 'package:woody_app/core/storage/r2_upload_client.dart';
import 'package:woody_app/shared/models/chat.dart';
import 'package:woody_app/shared/models/chat_message.dart';
import 'package:woody_app/shared/repositories/woody_chat_repositories.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockUploads extends Mock implements R2UploadClient {}

/// A [RealtimeConnection] the test drives by hand — emit frames without a
/// real socket. Mirrors the fake used by the realtime-service test.
class _FakeConnection implements RealtimeConnection {
  final _ready = Completer<void>()..complete();
  final _frames = StreamController<dynamic>.broadcast();

  void emit(dynamic frame) => _frames.add(frame);

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<dynamic> get stream => _frames.stream;

  @override
  Future<void> close() async {
    if (!_frames.isClosed) await _frames.close();
  }
}

/// Backend `chat_message` realtime payload (recipient-only, full row minus
/// the always-null `read_at` of a brand-new message).
Map<String, dynamic> _eventMsg({
  required String id,
  required String chatId,
  String role = 'seller',
}) => {
  'id': id,
  'chat_id': chatId,
  'sender_id': 'se1',
  'sender_role': role,
  'body': 'yangi xabar',
  'attachment_url': null,
  'created_at': '2026-01-01T00:00:00Z',
};

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

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(R2Bucket.chatAttachments);
  });

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

  ({WoodyChatRepository repo, _FakeAdapter adapter}) makeWithUploads(
    R2UploadClient uploads,
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
    return (
      repo: WoodyChatRepository(api: api, uploads: uploads),
      adapter: adapter,
    );
  }

  test('listMyChats maps the chat rows', () async {
    final h = make((_) => (200, jsonEncode([_chat('ch1')])));

    final chats = await h.repo.listMyChats();

    expect(chats.single.id, 'ch1');
    expect(chats.single.orderId, 'o1');
    expect(h.adapter.calls.single.uri.path, endsWith('/chats'));
    // No viewer role → no scope param, the backend returns both sides.
    expect(h.adapter.calls.single.uri.queryParameters, isEmpty);
  });

  test('listMyChats scopes to the viewer role via ?mode=', () async {
    final h = make((_) => (200, jsonEncode([_chat('ch1')])));

    await h.repo.listMyChats(as: ChatSenderRole.seller);

    expect(h.adapter.calls.single.uri.queryParameters['mode'], 'seller');
  });

  test('listMyChats returns [] without HTTP for a guest session', () async {
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
    await guestStore.read();

    final adapter = _FakeAdapter((_) => (200, jsonEncode([_chat('ch1')])));
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://test.local',
        validateStatus: (s) => s != null && s < 500,
      ),
    )..httpClientAdapter = adapter;
    final api = WoodyApiClient(tokens: guestStore, dio: dio);
    final repo = WoodyChatRepository(api: api, tokens: guestStore);

    expect(await repo.listMyChats(as: ChatSenderRole.customer), isEmpty);
    expect(adapter.calls, isEmpty);
  });

  test('listMyChats maps the last-message read-receipt fields', () async {
    final row = {
      ..._chat('ch1'),
      'last_message_at': '2026-06-13T11:10:00Z',
      'last_message_preview': 'salom',
      'last_message_sender_role': 'customer',
      'last_message_read_at': '2026-06-13T11:12:00Z',
    };
    final h = make((_) => (200, jsonEncode([row])));

    final chat = (await h.repo.listMyChats()).single;

    expect(chat.lastMessageSenderRole, ChatSenderRole.customer);
    expect(chat.lastMessageRead, isTrue);
    expect(chat.lastMessageIsMine(ChatSenderRole.customer), isTrue);
    expect(chat.lastMessageIsMine(ChatSenderRole.seller), isFalse);
  });

  test('listMyChats leaves receipt fields null when absent / unread', () async {
    final row = {
      ..._chat('ch1'),
      'last_message_sender_role': 'seller',
      // last_message_read_at omitted → not yet read
    };
    final h = make((_) => (200, jsonEncode([row])));

    final chat = (await h.repo.listMyChats()).single;

    expect(chat.lastMessageSenderRole, ChatSenderRole.seller);
    expect(chat.lastMessageRead, isFalse);
  });

  test(
    'listMyChats degrades an unknown sender_role to null (no throw)',
    () async {
      // Production only ever writes customer/seller, but a legacy/garbage value
      // must degrade to null — the tile then shows no receipt — never throw and
      // tear down the whole list. Locks the documented degrade-not-throw contract.
      final row = {..._chat('ch1'), 'last_message_sender_role': 'admin'};
      final h = make((_) => (200, jsonEncode([row])));

      final chat = (await h.repo.listMyChats()).single;

      expect(chat.lastMessageSenderRole, isNull);
      expect(chat.lastMessageIsMine(ChatSenderRole.customer), isFalse);
      expect(chat.lastMessageIsMine(ChatSenderRole.seller), isFalse);
    },
  );

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

  group('realtime wiring', () {
    // Builds a started WoodyRealtimeService over a hand-driven fake socket,
    // plus a repo bound to it. `conn.emit(...)` injects frames.
    Future<
      ({
        WoodyChatRepository repo,
        _FakeAdapter adapter,
        WoodyRealtimeService rt,
        _FakeConnection conn,
      })
    >
    makeRealtime((int, String) Function(RequestOptions) responder) async {
      final adapter = _FakeAdapter(responder);
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://test.local',
          validateStatus: (s) => s != null && s < 500,
        ),
      )..httpClientAdapter = adapter;
      final api = WoodyApiClient(tokens: store, dio: dio);
      late _FakeConnection conn;
      final rt = WoodyRealtimeService(
        tokens: store,
        baseUrlOverride: 'https://api.woody.test',
        connector: (uri, {required accessToken}) => conn = _FakeConnection(),
      );
      await rt.start();
      final repo = WoodyChatRepository(api: api, realtime: rt);
      return (repo: repo, adapter: adapter, rt: rt, conn: conn);
    }

    void emitChat(_FakeConnection conn, Map<String, dynamic> data) =>
        conn.emit(jsonEncode({'type': 'chat_message', 'data': data}));

    void emitRead(_FakeConnection conn, String chatId) => conn.emit(
      jsonEncode({
        'type': 'chat_read',
        'data': {'chat_id': chatId, 'reader_role': 'seller'},
      }),
    );

    test('messagesStream lifts a chat_message frame for THIS chat', () async {
      final h = await makeRealtime((_) => (200, '[]'));
      addTearDown(() => h.rt.stop());

      final received = <ChatMessage>[];
      final sub = h.repo.messagesStream('ch1').listen(received.add);
      await pumpEventQueue();

      emitChat(h.conn, _eventMsg(id: 'm1', chatId: 'ch1'));
      emitChat(h.conn, _eventMsg(id: 'm2', chatId: 'other'));
      await pumpEventQueue();

      expect(received.map((m) => m.id), ['m1']);
      expect(received.single.senderRole, ChatSenderRole.seller);
      await sub.cancel();
    });

    test('messagesStream is empty without a realtime service', () async {
      final h = make((_) => (200, '[]')); // built WITHOUT realtime
      expect(h.repo.messagesStream('ch1'), emitsDone);
    });

    test('myChatsStream re-fetches on a chat_message frame', () async {
      var calls = 0;
      final h = await makeRealtime((_) {
        calls++;
        return (200, jsonEncode([_chat('ch1')]));
      });
      addTearDown(() => h.rt.stop());

      final emissions = <List<Chat>>[];
      final sub = h.repo.myChatsStream().listen(emissions.add);
      await pumpEventQueue(); // initial snapshot fetch

      expect(calls, 1);
      expect(emissions, hasLength(1));

      emitChat(h.conn, _eventMsg(id: 'm1', chatId: 'ch1'));
      await pumpEventQueue();

      expect(calls, 2); // the frame triggered a second GET
      expect(emissions, hasLength(2));
      await sub.cancel();
    });

    test(
      'myChatsStream re-fetches on a chat_read frame (live receipt)',
      () async {
        var calls = 0;
        final h = await makeRealtime((_) {
          calls++;
          return (200, jsonEncode([_chat('ch1')]));
        });
        addTearDown(() => h.rt.stop());

        final sub = h.repo.myChatsStream().listen((_) {});
        await pumpEventQueue(); // initial snapshot fetch
        expect(calls, 1);

        // The other party opened the thread → our outgoing tick must flip, so
        // the list refetches and re-reads last_message_read_at.
        emitRead(h.conn, 'ch1');
        await pumpEventQueue();

        expect(calls, 2);
        await sub.cancel();
      },
    );

    test('nudgeFromPush forces a chat-list re-fetch (FCM fallback)', () async {
      var calls = 0;
      final h = await makeRealtime((_) {
        calls++;
        return (200, jsonEncode([_chat('ch1')]));
      });
      addTearDown(() => h.rt.stop());

      final sub = h.repo.myChatsStream().listen((_) {});
      await pumpEventQueue();
      expect(calls, 1);

      h.repo.nudgeFromPush();
      await pumpEventQueue();

      expect(calls, 2);
      await sub.cancel();
    });

    test('orderEventsStream fires on a notification for THIS order', () async {
      final h = await makeRealtime((_) => (200, '[]'));
      addTearDown(() => h.rt.stop());

      var ticks = 0;
      final sub = h.repo.orderEventsStream('order-1').listen((_) => ticks++);
      await pumpEventQueue();

      void emitNotif(String refId) => h.conn.emit(
        jsonEncode({
          'type': 'notification',
          'data': {'reference_id': refId, 'type': 'order_status'},
        }),
      );
      emitNotif('order-1'); // matches → tick
      emitNotif('order-9'); // different order → ignored
      await pumpEventQueue();

      expect(ticks, 1);
      await sub.cancel();
    });

    test(
      'markAsRead nudges the chat list (badge drop after reading)',
      () async {
        var listGets = 0;
        final h = await makeRealtime((options) {
          if (options.uri.path.endsWith('/read')) return (200, '{}');
          listGets++;
          return (200, jsonEncode([_chat('ch1')]));
        });
        addTearDown(() => h.rt.stop());

        final sub = h.repo.myChatsStream().listen((_) {});
        await pumpEventQueue();
        expect(listGets, 1);

        await h.repo.markAsRead('ch1');
        await pumpEventQueue();

        expect(listGets, 2); // reading re-pulled the list so the badge updates
        await sub.cancel();
      },
    );
  });

  group('image attachments', () {
    final imgBytes = Uint8List.fromList([1, 2, 3, 4]);

    void stubUpload(_MockUploads uploads, {required String? publicUrl}) {
      when(
        () => uploads.upload(
          bucket: any(named: 'bucket'),
          path: any(named: 'path'),
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
        ),
      ).thenAnswer(
        (_) async => R2UploadResult(
          bucket: R2Bucket.chatAttachments,
          path: 'p',
          publicUrl: publicUrl,
        ),
      );
    }

    test('reports unavailable when no uploader is wired', () async {
      final h = make((_) => (200, '{}')); // repo built WITHOUT uploads
      await expectLater(
        () => h.repo.sendImage(
          chatId: 'ch1',
          bytes: imgBytes,
          mimeType: 'image/jpeg',
          as: ChatSenderRole.customer,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'chat_image_unavailable',
          ),
        ),
      );
    });

    test('degrades (no POST) when the bucket returns no public URL', () async {
      final uploads = _MockUploads();
      stubUpload(uploads, publicUrl: null);
      final h = makeWithUploads(uploads, (_) => (201, jsonEncode(_msg('m1'))));

      await expectLater(
        () => h.repo.sendImage(
          chatId: 'ch1',
          bytes: imgBytes,
          mimeType: 'image/jpeg',
          as: ChatSenderRole.customer,
        ),
        throwsA(isA<StateError>()),
      );
      // Never persisted an unrenderable message.
      expect(h.adapter.calls, isEmpty);
    });

    test('uploads then POSTs attachment_url + caption on success', () async {
      final uploads = _MockUploads();
      stubUpload(uploads, publicUrl: 'https://cdn.woody.uz/chat/x.jpg');
      final h = makeWithUploads(uploads, (_) => (201, jsonEncode(_msg('m1'))));

      final msg = await h.repo.sendImage(
        chatId: 'ch1',
        bytes: imgBytes,
        mimeType: 'image/jpeg',
        as: ChatSenderRole.customer,
        caption: 'salom',
      );

      expect(msg.id, 'm1');
      final call = h.adapter.calls.single;
      expect(call.method, 'POST');
      expect(call.uri.path, endsWith('/chats/ch1/messages'));
      expect(
        (call.data as Map)['attachment_url'],
        'https://cdn.woody.uz/chat/x.jpg',
      );
      expect((call.data as Map)['body'], 'salom');
      verify(
        () => uploads.upload(
          bucket: R2Bucket.chatAttachments,
          path: any(named: 'path'),
          bytes: imgBytes,
          contentType: 'image/jpeg',
        ),
      ).called(1);
    });
  });
}
