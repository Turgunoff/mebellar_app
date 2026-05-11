import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mebellar_app/config/app_mode.dart';
import 'package:mebellar_app/core/connectivity/connectivity_service.dart';
import 'package:mebellar_app/core/deep_links/deep_link_service.dart';
import 'package:mebellar_app/core/storage/cache_store.dart';

void main() {
  setUpAll(() {
    Hive.init('./test/.hive');
  });

  group('MockConnectivityService', () {
    test('starts online and emits status changes', () async {
      final service = MockConnectivityService();
      expect(service.isOnline, isTrue);
      final received = <ConnectivityStatus>[];
      final sub = service.watch().listen(received.add);
      service.overrideStatus(ConnectivityStatus.offline);
      service.overrideStatus(ConnectivityStatus.online);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received,
          [ConnectivityStatus.offline, ConnectivityStatus.online]);
      await sub.cancel();
      await service.dispose();
    });

    test('repeating the same status does not emit duplicates', () async {
      final service = MockConnectivityService();
      final received = <ConnectivityStatus>[];
      final sub = service.watch().listen(received.add);
      service.overrideStatus(ConnectivityStatus.online); // already online
      service.overrideStatus(ConnectivityStatus.offline);
      service.overrideStatus(ConnectivityStatus.offline); // duplicate
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received, [ConnectivityStatus.offline]);
      await sub.cancel();
      await service.dispose();
    });
  });

  group('MockDeepLinkService URI routing', () {
    test('mebellar:// scheme routes to customer mode', () {
      final target =
          MockDeepLinkService.parse('mebellar://orders/ord-1001');
      expect(target?.mode, AppMode.customer);
      expect(target?.route, '/orders/ord-1001');
    });

    test('https://mebellar.uz/... routes the same way', () {
      final target =
          MockDeepLinkService.parse('https://mebellar.uz/orders/ord-1001');
      expect(target?.mode, AppMode.customer);
      expect(target?.route, '/orders/ord-1001');
    });

    test('seller-prefixed routes flip the mode', () {
      final target =
          MockDeepLinkService.parse('mebellar://seller/products/sp-7');
      expect(target?.mode, AppMode.seller);
      expect(target?.route, '/seller/products/sp-7');
    });

    test('unknown hosts return null (drop)', () {
      expect(MockDeepLinkService.parse('https://example.com/foo'), isNull);
      expect(MockDeepLinkService.parse('not-a-uri at all'), anyOf(isNull, isA<DeepLinkTarget>()));
    });

    test('search query string survives parsing', () {
      final target = MockDeepLinkService.parse(
          'https://mebellar.uz/catalog?category=sofas');
      expect(target?.mode, AppMode.customer);
      expect(target?.route, contains('catalog'));
      expect(target?.route, contains('category=sofas'));
    });
  });

  group('CacheStore TTL', () {
    late Box box;

    setUp(() async {
      box = await Hive.openBox(
          'test_cache_${DateTime.now().millisecondsSinceEpoch}');
    });

    tearDown(() async {
      await box.clear();
      await box.close();
    });

    test('putJson + getJson roundtrip within TTL', () {
      final store = CacheStore(box);
      store.putJson('k', {'a': 1}, ttl: const Duration(minutes: 5));
      final loaded = store.getJson('k', (decoded) => decoded as Map);
      expect(loaded?['a'], 1);
    });

    test('expired entries return null and are cleared', () {
      final store = CacheStore(box);
      // Manually inject an entry with a past expiry timestamp.
      box.put('stale', '"value"');
      box.put('stale__ts',
          DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String());
      expect(store.getJson('stale', (d) => d), isNull);
      // Stale rows are deleted on access so subsequent calls are clean.
      expect(box.get('stale'), isNull);
    });

    test('invalidate by prefix deletes namespaced rows only', () {
      final store = CacheStore(box);
      store.putJson('products:1', {'id': 1});
      store.putJson('products:2', {'id': 2});
      store.putJson('cart:1', {'id': 'c1'});
      store.invalidate('products:');
      expect(store.getJson('products:1', (d) => d), isNull);
      expect(store.getJson('products:2', (d) => d), isNull);
      expect(store.getJson('cart:1', (d) => d as Map)?['id'], 'c1');
    });
  });
}
