import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_designer_repository.dart';
import 'package:woody_app/customer/features/ai_designer/models/ai_chat_message.dart';

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

  ({WoodyAiDesignerRepository repo, _FakeAdapter adapter}) make(
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
    return (repo: WoodyAiDesignerRepository(api), adapter: adapter);
  }

  test(
    'fetchHistory expands each turn into a user + AI message, oldest-first',
    () async {
      final h = make(
        (_) => (
          200,
          jsonEncode({
            'turns': [
              {
                'log_id': 'log-1',
                'user_message': 'salom',
                'has_image': false,
                'ai_response': 'Qanday yordam bera olaman?',
                'user_rating': null,
                'created_at': '2026-01-01T10:00:00.000Z',
              },
              {
                'log_id': 'log-2',
                'user_message': 'divan kerak',
                'has_image': true,
                'ai_response': 'Mana mos divanlar',
                'user_rating': 'liked',
                'created_at': '2026-01-01T10:05:00.000Z',
              },
            ],
          }),
        ),
      );

      final msgs = await h.repo.fetchHistory();

      final call = h.adapter.calls.single;
      expect(call.method, 'GET');
      expect(call.uri.path, endsWith('/ai/chat/history'));
      // 2 turns → 4 messages, oldest-first, user before its AI reply.
      expect(msgs.map((m) => m.text).toList(), [
        'salom',
        'Qanday yordam bera olaman?',
        'divan kerak',
        'Mana mos divanlar',
      ]);
      expect(msgs[0].isUser, isTrue);
      expect(msgs[1].isUser, isFalse);
      // The AI reply keeps its backend log id (so 👍/👎 still works) + rating.
      expect(msgs[1].logId, 'log-1');
      expect(msgs[3].logId, 'log-2');
      expect(msgs[3].userRating, 'liked');
      // The AI bubble sorts strictly AFTER its question (created_at + 1ms).
      expect(msgs[1].timestamp.isAfter(msgs[0].timestamp), isTrue);
    },
  );

  test('fetchHistory drops the AI bubble when ai_response is null', () async {
    final h = make(
      (_) => (
        200,
        jsonEncode({
          'turns': [
            {
              'log_id': 'log-1',
              'user_message': 'salom',
              'has_image': false,
              'ai_response': null,
              'user_rating': null,
              'created_at': '2026-01-01T10:00:00.000Z',
            },
          ],
        }),
      ),
    );

    final msgs = await h.repo.fetchHistory();
    expect(msgs, hasLength(1));
    expect(msgs.single.isUser, isTrue);
    expect(msgs.single.text, 'salom');
  });

  test(
    'fetchHistory throws on a server error so the cubit can fall back',
    () async {
      final h = make((_) => (500, '{}'));
      await expectLater(h.repo.fetchHistory(), throwsA(anything));
    },
  );

  // Regression: the backend AiChatBody rejects empty history-turn text
  // (min_length=1). Image-only user turns + degraded AI replies are stored
  // locally with empty text; the repo must drop them so the request isn't 422'd.
  test('chat drops blank-text history turns from the payload', () async {
    final h = make(
      (_) => (200, jsonEncode({'available': true, 'reply': 'ok'})),
    );
    final ts = DateTime(2026, 1, 1);
    await h.repo.chat(
      message: 'need a sofa',
      history: [
        AiChatMessage(id: '1', text: 'hi', isUser: true, timestamp: ts),
        AiChatMessage(
          id: '2',
          text: '',
          isUser: false,
          timestamp: ts,
        ), // empty AI reply
        AiChatMessage(
          id: '3',
          text: '   ',
          isUser: true,
          timestamp: ts,
        ), // image-only
        AiChatMessage(
          id: '4',
          text: 'show sofas',
          isUser: false,
          timestamp: ts,
        ),
      ],
    );
    final data = h.adapter.calls.single.data;
    final body = (data is String ? jsonDecode(data) : data) as Map;
    expect(body['message'], 'need a sofa');
    final sent = (body['history'] as List).cast<Map>();
    expect(sent.map((t) => t['text']).toList(), ['hi', 'show sofas']);
    expect(sent.map((t) => t['role']).toList(), ['user', 'assistant']);
  });

  // Regression: the backend caps history at 20 turns (max_length=20). The local
  // thread grows unbounded, so the repo must send only the most recent 20.
  test('chat caps history to the most recent 20 turns', () async {
    final h = make(
      (_) => (200, jsonEncode({'available': true, 'reply': 'ok'})),
    );
    final ts = DateTime(2026, 1, 1);
    final history = [
      for (var i = 0; i < 25; i++)
        AiChatMessage(id: '$i', text: 'm$i', isUser: i.isEven, timestamp: ts),
    ];
    await h.repo.chat(message: 'hello', history: history);
    final data = h.adapter.calls.single.data;
    final body = (data is String ? jsonDecode(data) : data) as Map;
    final sent = (body['history'] as List).cast<Map>();
    expect(sent, hasLength(20));
    // The newest 20 → m5..m24 (the oldest 5 are dropped).
    expect(sent.first['text'], 'm5');
    expect(sent.last['text'], 'm24');
  });

  test('chat sends the pre-uploaded image_url + image_path', () async {
    final h = make(
      (_) => (200, jsonEncode({'available': true, 'reply': 'ok'})),
    );
    await h.repo.chat(
      message: 'mana xonam',
      imageUrl: 'https://cdn.woody.uz/ai-chat-images/u1/abc.webp',
      imagePath: 'u1/abc.webp',
    );
    final data = h.adapter.calls.single.data;
    final body = (data is String ? jsonDecode(data) : data) as Map;
    expect(
      body['image_url'],
      'https://cdn.woody.uz/ai-chat-images/u1/abc.webp',
    );
    expect(body['image_path'], 'u1/abc.webp');
    // The legacy inline path must be gone — we upload to R2 first now.
    expect(body.containsKey('image_base64'), isFalse);
  });

  test(
    'fetchHistory restores image_url, and flags a purged photo as expired',
    () async {
      final h = make(
        (_) => (
          200,
          jsonEncode({
            'turns': [
              {
                'log_id': 'log-1',
                'user_message': 'mana xonam',
                'has_image': true,
                'image_url': 'https://cdn.woody.uz/ai-chat-images/u1/a.webp',
                'ai_response': 'Mana divanlar',
                'user_rating': null,
                'created_at': '2026-06-01T10:00:00.000Z',
              },
              {
                'log_id': 'log-2',
                'user_message': 'eski rasm',
                'has_image': true, // photo purged by retention → no image_url
                'image_url': null,
                'ai_response': 'javob',
                'user_rating': null,
                'created_at': '2026-01-01T10:00:00.000Z',
              },
            ],
          }),
        ),
      );

      final msgs = await h.repo.fetchHistory();
      final firstUser = msgs.firstWhere((m) => m.text == 'mana xonam');
      expect(
        firstUser.imageUrl,
        'https://cdn.woody.uz/ai-chat-images/u1/a.webp',
      );
      expect(firstUser.hasImage, isTrue);

      final purgedUser = msgs.firstWhere((m) => m.text == 'eski rasm');
      // Expired: still flagged hasImage (→ "media expired" tile) but no URL.
      expect(purgedUser.hasImage, isTrue);
      expect(purgedUser.imageUrl, isNull);
    },
  );
}
