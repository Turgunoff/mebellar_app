import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/auth/auth_repository.dart';
import 'package:woody_app/core/network/api_error.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

const _json = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Routes every request through a per-test [responder] and records the
/// [RequestOptions] so the body/method/path can be asserted.
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

// A structurally valid JWT (unverified) carrying the given claims.
String _jwt(Map<String, dynamic> payload) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg(payload)}.sig';
}

void main() {
  late _MockSecureStorage storage;
  late TokenStore store;

  setUp(() {
    storage = _MockSecureStorage();
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
  });

  ({AuthRepository repo, _FakeAdapter adapter}) makeRepo(
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
    return (repo: AuthRepository(api: api, tokens: store), adapter: adapter);
  }

  test('requestOtp returns the server cooldown', () async {
    final h = makeRepo((_) => (200, '{"cooldown_seconds":42}'));
    expect(await h.repo.requestOtp('+998901112233'), 42);
    expect(h.adapter.calls.single.uri.path, endsWith('/auth/otp/request'));
  });

  test('requestOtp defaults the cooldown to 0 when absent', () async {
    final h = makeRepo((_) => (200, '{}'));
    expect(await h.repo.requestOtp('+998901112233'), 0);
  });

  test('verifyOtp parses tokens, persists them, and exposes the identity',
      () async {
    final access = _jwt({'sub': 'user-1', 'phone': '+998901112233'});
    final h = makeRepo((opts) {
      if (opts.uri.path.endsWith('/auth/otp/verify')) {
        return (
          200,
          '{"access_token":"$access","refresh_token":"R1","expires_in":900}',
        );
      }
      return (200, '{}');
    });

    final pair = await h.repo.verifyOtp('+998901112233', '0000');

    expect(pair.accessToken, access);
    expect(pair.refreshToken, 'R1');
    expect(store.current?.accessToken, access); // written to the store
    expect(h.repo.isAuthenticated, isTrue);
    expect(h.repo.currentUserId, 'user-1');
    expect(h.repo.currentUserPhone, '+998901112233');
  });

  test('verifyOtp throws on a malformed token response and writes nothing',
      () async {
    final h = makeRepo((_) => (200, '{"refresh_token":"R1"}')); // no access

    await expectLater(
      () => h.repo.verifyOtp('+998901112233', '0000'),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', 'malformed_token_response'),
      ),
    );
    expect(store.current, isNull);
    expect(h.repo.isAuthenticated, isFalse);
  });

  test('signOut clears the local session even when the backend logout fails',
      () async {
    await store.write(
      const TokenPair(accessToken: 'A', refreshToken: 'R'),
    );
    final h = makeRepo((opts) {
      if (opts.uri.path.endsWith('/auth/logout')) return (400, '{"detail":"x"}');
      return (200, '{}');
    });

    await h.repo.signOut();

    expect(store.current, isNull);
    expect(h.repo.isAuthenticated, isFalse);
    expect(
      h.adapter.calls.any((c) => c.uri.path.endsWith('/auth/logout')),
      isTrue,
    );
  });

  test('fetchMe maps the /me payload', () async {
    await store.write(
      TokenPair(accessToken: _jwt({'sub': 'user-1'}), refreshToken: 'R'),
    );
    final h = makeRepo(
      (_) => (200, '{"id":"user-1","full_name":"Ali","preferred_language":"ru"}'),
    );

    final me = await h.repo.fetchMe();

    expect(me.id, 'user-1');
    expect(me.fullName, 'Ali');
    expect(me.preferredLanguage, 'ru');
    expect(me.hasProfile, isTrue);
  });

  test('updateProfile sends only the provided fields and maps the result',
      () async {
    await store.write(
      TokenPair(accessToken: _jwt({'sub': 'user-1'}), refreshToken: 'R'),
    );
    final h = makeRepo(
      (_) => (200, '{"id":"user-1","full_name":"Yangi"}'),
    );

    final me = await h.repo.updateProfile(fullName: 'Yangi');

    expect(me.fullName, 'Yangi');
    final patch = h.adapter.calls.single;
    expect(patch.method, 'PATCH');
    expect(patch.uri.path, endsWith('/me'));
    final body = patch.data as Map<String, dynamic>;
    expect(body['full_name'], 'Yangi');
    expect(body.containsKey('email'), isFalse); // unset fields omitted
  });
}
