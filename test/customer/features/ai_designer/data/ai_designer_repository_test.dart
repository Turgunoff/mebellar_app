import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/customer/features/ai_designer/data/ai_designer_repository.dart';

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

  test('fetchHistory expands each turn into a user + AI message, oldest-first', () async {
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
  });

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

  test('fetchHistory throws on a server error so the cubit can fall back', () async {
    final h = make((_) => (500, '{}'));
    await expectLater(h.repo.fetchHistory(), throwsA(anything));
  });
}
