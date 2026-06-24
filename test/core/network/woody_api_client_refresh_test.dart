import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/api_error.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';

/// Mocktail double for the platform secure storage, backed by an in-memory
/// map. We use a REAL [TokenStore] on top so the test exercises its caching —
/// the cache is part of what made the concurrent-refresh bug possible.
class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

const _json = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Programmable [Dio] adapter. Returns 401 for `/me` until the caller holds
/// the [validAccess] token, counts hits on `/auth/refresh`, and lets each
/// test dictate the refresh response status.
class _FakeAdapter implements HttpClientAdapter {
  int refreshHits = 0;
  int rejectedHits = 0;
  int refreshStatus = 200;
  final String validAccess = 'NEW';

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/auth/refresh')) {
      refreshHits++;
      // Hold the in-flight refresh open briefly so every concurrent 401
      // that is going to share the single-flight future has arrived.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (refreshStatus != 200) {
        return ResponseBody.fromString(
          '{"detail":"x"}',
          refreshStatus,
          headers: _json,
        );
      }
      return ResponseBody.fromString(
        '{"access_token":"$validAccess",'
        '"refresh_token":"NEWREFRESH","expires_in":900}',
        200,
        headers: _json,
      );
    }
    final auth = options.headers['Authorization'];
    if (auth == 'Bearer $validAccess') {
      return ResponseBody.fromString('{"ok":true}', 200, headers: _json);
    }
    rejectedHits++;
    return ResponseBody.fromString(
      '{"detail":"not_authenticated"}',
      401,
      headers: _json,
    );
  }
}

WoodyApiClient _client(_FakeAdapter adapter, TokenStore store) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://test.local',
      validateStatus: (status) => status != null && status < 500,
    ),
  )..httpClientAdapter = adapter;
  return WoodyApiClient(tokens: store, dio: dio);
}

void main() {
  late _MockSecureStorage storage;
  late TokenStore store;

  setUp(() async {
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
    await store.write(
      const TokenPair(accessToken: 'OLD', refreshToken: 'OLDREFRESH'),
    );
  });

  test(
    'concurrent 401s trigger exactly ONE refresh (single-flight) and all '
    'requests recover',
    () async {
      final adapter = _FakeAdapter();
      final client = _client(adapter, store);

      // A cold-start burst: eight authenticated requests fire at once, all
      // carrying the now-expired access token.
      final results = await Future.wait(
        List.generate(8, (_) => client.get<Map<String, dynamic>>('/me')),
      );

      // The rotating refresh token must be presented to the server once —
      // a second use would trip the backend's reuse-detection and scorch
      // the whole session.
      expect(adapter.refreshHits, 1);
      for (final r in results) {
        expect(r['ok'], true);
      }
      // Session survived and now holds the rotated pair.
      final pair = await store.read();
      expect(pair?.accessToken, 'NEW');
      expect(pair?.refreshToken, 'NEWREFRESH');
    },
  );

  test('a transient refresh failure (5xx) does NOT sign the user out',
      () async {
    final adapter = _FakeAdapter()..refreshStatus = 500;
    final client = _client(adapter, store);

    final forced = <void>[];
    final sub = client.forcedSignOuts.listen(forced.add);

    await expectLater(
      client.get<Map<String, dynamic>>('/me'),
      throwsA(isA<ApiError>().having((e) => e.isUnauthorized, 'isUnauthorized',
          true)),
    );

    expect(adapter.refreshHits, 1);
    expect(forced, isEmpty, reason: 'transient error must not wipe session');
    final pair = await store.read();
    expect(pair?.refreshToken, 'OLDREFRESH', reason: 'token must be retained');

    await sub.cancel();
  });

  test('a definitive 401 on refresh DOES force a sign-out', () async {
    final adapter = _FakeAdapter()..refreshStatus = 401;
    final client = _client(adapter, store);

    final forced = <void>[];
    final sub = client.forcedSignOuts.listen(forced.add);

    await expectLater(
      client.get<Map<String, dynamic>>('/me'),
      throwsA(isA<ApiError>()),
    );

    expect(forced, hasLength(1));
    final pair = await store.read();
    expect(pair, isNull, reason: 'invalid refresh token clears the session');

    await sub.cancel();
  });

  test('a 403 (account_blocked) on refresh DOES force a sign-out', () async {
    // An admin block revokes the whole refresh chain server-side and the
    // refresh endpoint answers 403 account_blocked — retrying can never
    // succeed, so keeping the session would strand the user in a loop of
    // failing requests instead of bouncing them to login.
    final adapter = _FakeAdapter()..refreshStatus = 403;
    final client = _client(adapter, store);

    final forced = <void>[];
    final sub = client.forcedSignOuts.listen(forced.add);

    await expectLater(
      client.get<Map<String, dynamic>>('/me'),
      throwsA(isA<ApiError>()),
    );

    expect(forced, hasLength(1));
    final pair = await store.read();
    expect(pair, isNull, reason: 'blocked account clears the session');

    await sub.cancel();
  });

  test(
    'a concurrent 401 burst forces sign-out EXACTLY ONCE (one teardown, not N)',
    () async {
      // A deleted account: every authed call 401s and each refresh attempt is
      // rejected. The heavy teardown wired to `forcedSignOuts` (Hive/image-cache
      // wipe + Phoenix.rebirth) must run once, not once per in-flight request.
      final adapter = _FakeAdapter()..refreshStatus = 401;
      final client = _client(adapter, store);

      final forced = <void>[];
      final sub = client.forcedSignOuts.listen(forced.add);

      await Future.wait(
        List.generate(
          8,
          (_) => client
              .get<Map<String, dynamic>>('/me')
              .catchError((_) => <String, dynamic>{}),
        ),
      );

      expect(adapter.refreshHits, 1, reason: 'single-flight refresh');
      expect(forced, hasLength(1), reason: 'one forced sign-out for the burst');
      expect(await store.read(), isNull);

      await sub.cancel();
    },
  );

  test('an anonymous request that 401s never forces a sign-out', () async {
    // The refresh/logout/OTP calls (and any explicitly anonymous request) carry
    // the anonymous flag; a 401 on them must NOT trigger the global force-logout
    // or it would loop (the forced logout itself makes anonymous calls).
    final adapter = _FakeAdapter();
    final client = _client(adapter, store);

    final forced = <void>[];
    final sub = client.forcedSignOuts.listen(forced.add);

    await expectLater(
      client.get<Map<String, dynamic>>('/whatever', anonymous: true),
      throwsA(isA<ApiError>()),
    );

    expect(adapter.refreshHits, 0, reason: 'anonymous never refreshes');
    expect(forced, isEmpty, reason: 'anonymous 401 must not force sign-out');
    final pair = await store.read();
    expect(pair?.refreshToken, 'OLDREFRESH', reason: 'session retained');

    await sub.cancel();
  });

  test(
    'an already-expired access token refreshes PROACTIVELY — the burst never '
    '401s and the rotating refresh token is presented exactly once',
    () async {
      // The day-later cold start: the stored access token is already past its
      // 15-minute expiry while the 30-day refresh token is still valid.
      await store.write(
        TokenPair(
          accessToken: 'OLD',
          refreshToken: 'OLDREFRESH',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      final adapter = _FakeAdapter();
      final client = _client(adapter, store);

      // A cold-start / post-rebirth burst of eight authenticated requests.
      final results = await Future.wait(
        List.generate(8, (_) => client.get<Map<String, dynamic>>('/me')),
      );

      // Refreshed up front, exactly once (single-flight) — so not a single
      // request ever went out with the expired token and got a 401. This is
      // what keeps the rotating refresh token from being presented twice and
      // tripping the backend's reuse-detection.
      expect(adapter.refreshHits, 1);
      expect(
        adapter.rejectedHits,
        0,
        reason: 'proactive refresh means no request leaves with an expired token',
      );
      for (final r in results) {
        expect(r['ok'], true);
      }
      final pair = await store.read();
      expect(pair?.accessToken, 'NEW');
      expect(pair?.refreshToken, 'NEWREFRESH');
    },
  );
}
