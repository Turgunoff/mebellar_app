import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/shared/repositories/woody_banner_repository.dart';
import 'package:woody_app/shared/repositories/woody_category_repository.dart';

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

  ({WoodyApiClient api, _FakeAdapter adapter}) client(
    (int, String) Function(RequestOptions) responder,
  ) {
    final adapter = _FakeAdapter(responder);
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://test.local',
        validateStatus: (s) => s != null && s < 500,
      ),
    )..httpClientAdapter = adapter;
    return (api: WoodyApiClient(tokens: store, dio: dio), adapter: adapter);
  }

  group('WoodyCategoryRepository', () {
    test('list maps rows (with subcategories) and skips non-map entries',
        () async {
      final h = client((_) => (
            200,
            jsonEncode([
              {
                'id': 'c1',
                'name': 'Divanlar',
                'sort_order': 2,
                'subcategories': [
                  {'id': 's1', 'category_id': 'c1', 'name': 'Burchak divan'},
                ],
              },
              'junk', // not a map → filtered out
            ]),
          ));

      final cats = await WoodyCategoryRepository(api: h.api).list();

      expect(cats, hasLength(1));
      expect(cats.single.id, 'c1');
      expect(cats.single.name, 'Divanlar');
      expect(cats.single.sortOrder, 2);
      expect(cats.single.subcategories.single.name, 'Burchak divan');
      expect(h.adapter.calls.single.uri.path, endsWith('/catalog/categories'));
    });

    test('list returns empty for an empty array', () async {
      final h = client((_) => (200, '[]'));
      expect(await WoodyCategoryRepository(api: h.api).list(), isEmpty);
    });
  });

  group('WoodyBannerRepository', () {
    test('list maps flat rows and broadcasts the title to all locales',
        () async {
      final h = client((_) => (
            200,
            jsonEncode([
              {
                'id': 'b1',
                'image_url': 'x.jpg',
                'title': 'Aksiya',
                'action_type': 'category',
                'action_value': 'c1',
              },
            ]),
          ));

      final banners = await WoodyBannerRepository(api: h.api).list();

      expect(banners, hasLength(1));
      final b = banners.single;
      expect(b.id, 'b1');
      expect(b.imageUrl, 'x.jpg');
      expect(b.title?.uz, 'Aksiya');
      expect(b.title?.ru, 'Aksiya'); // broadcast to every locale
      expect(b.linkType, 'category');
      expect(b.linkTarget, 'c1');
      expect(h.adapter.calls.single.uri.path, endsWith('/catalog/banners'));
    });
  });
}
