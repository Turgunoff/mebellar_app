import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

const _json = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Records every request it serves so tests can assert on the headers the
/// interceptor stamped.
class _HeaderCaptureAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('{"ok":true}', 200, headers: _json);
  }
}

void main() {
  late _MockSecureStorage storage;
  late TokenStore store;
  late _HeaderCaptureAdapter adapter;

  setUp(() {
    storage = _MockSecureStorage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    store = TokenStore(storage);
    adapter = _HeaderCaptureAdapter();
  });

  WoodyApiClient client({String Function()? locale}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://test.local',
        validateStatus: (status) => status != null && status < 500,
      ),
    )..httpClientAdapter = adapter;
    return WoodyApiClient(tokens: store, locale: locale, dio: dio);
  }

  test(
    'stamps Accept-Language from the live locale on every request',
    () async {
      var lang = 'uz';
      final api = client(locale: () => lang);

      await api.get<Map<String, dynamic>>('/catalog/categories');
      // The resolver is consulted per request — a language switch applies to
      // the very next call without rebuilding the client.
      lang = 'ru';
      await api.post<Map<String, dynamic>>('/cart/items', body: {'qty': 1});

      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[0].headers['Accept-Language'], 'uz');
      expect(adapter.requests[1].headers['Accept-Language'], 'ru');
    },
  );

  test('sends no Accept-Language when no locale resolver is wired', () async {
    final api = client();

    await api.get<Map<String, dynamic>>('/catalog/categories');

    expect(
      adapter.requests.single.headers.containsKey('Accept-Language'),
      isFalse,
    );
  });

  test('a per-request localeOverride beats the live UI locale', () async {
    // The OTP request forces `uz` so the SMS template never follows the UI
    // language (only the Uzbek Eskiz template is approved + Retriever-safe).
    final api = client(locale: () => 'ru');

    await api.post<Map<String, dynamic>>(
      '/auth/otp/request',
      body: {'phone': '+998901112233'},
      anonymous: true,
      localeOverride: 'uz',
    );

    expect(adapter.requests.single.headers['Accept-Language'], 'uz');
  });
}
