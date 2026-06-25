import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/token_store.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('TokenStore.read', () {
    // TOK-01: a cold-start burst of authenticated requests (the interceptor
    // reads tokens per request) must hydrate through a single storage
    // round-trip, not one per caller.
    test('concurrent cold reads share one hydration round-trip', () async {
      final storage = _MockStorage();
      var accessReads = 0;
      when(() => storage.read(key: 'woody_access_token')).thenAnswer((_) async {
        accessReads++;
        // Hold the round-trip open so all five callers pile up mid-flight.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'access';
      });
      when(
        () => storage.read(key: 'woody_refresh_token'),
      ).thenAnswer((_) async => 'refresh');
      when(
        () => storage.read(key: 'woody_expires_at'),
      ).thenAnswer((_) async => null);

      final store = TokenStore(storage);
      final results = await Future.wait([
        store.read(),
        store.read(),
        store.read(),
        store.read(),
        store.read(),
      ]);

      expect(results.every((r) => r?.accessToken == 'access'), isTrue);
      expect(accessReads, 1); // single-flight: not 5

      // After hydration the cached value serves further reads with no storage.
      final again = await store.read();
      expect(again?.accessToken, 'access');
      expect(accessReads, 1);
    });

    test(
      'a write that lands mid-hydration is not clobbered by stale storage',
      () async {
        final storage = _MockStorage();
        when(() => storage.read(key: 'woody_access_token')).thenAnswer((
          _,
        ) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return 'old-access';
        });
        when(
          () => storage.read(key: 'woody_refresh_token'),
        ).thenAnswer((_) async => 'old-refresh');
        when(
          () => storage.read(key: 'woody_expires_at'),
        ).thenAnswer((_) async => null);
        when(
          () => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => storage.delete(key: any(named: 'key')),
        ).thenAnswer((_) async {});

        final store = TokenStore(storage);
        final reading = store.read(); // starts hydration, awaits storage
        await store.write(
          const TokenPair(accessToken: 'fresh', refreshToken: 'fresh-r'),
        );

        await reading; // hydration completes after the write
        final current = await store.read();
        expect(current?.accessToken, 'fresh');
      },
    );
  });

  group('TokenStore.clear', () {
    FlutterSecureStorage emptyStorage() {
      final storage = _MockStorage();
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => storage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});
      when(
        () => storage.write(key: any(named: 'key'), value: any(named: 'value')),
      ).thenAnswer((_) async {});
      return storage;
    }

    // Regression: a clear() on an already-empty store must NOT broadcast on
    // `changes`. A guest 401 drags the interceptor through _forceSignOut →
    // clear(); if that re-emitted `null`, NotificationsCubit (which listens to
    // the stream) reloaded, hit another guest 401, cleared again — an infinite
    // /notifications loop. Only a real signed-in → signed-out flip is an event.
    test('clear() on an already-empty store emits nothing', () async {
      final store = TokenStore(emptyStorage());
      final emissions = <TokenPair?>[];
      final sub = store.changes.listen(emissions.add);

      await store.clear();
      await store.clear();
      await Future<void>.delayed(Duration.zero);

      expect(emissions, isEmpty);
      await sub.cancel();
    });

    test('clear() after a real sign-in emits null exactly once', () async {
      final store = TokenStore(emptyStorage());
      await store.write(
        const TokenPair(accessToken: 'a', refreshToken: 'r'),
      );
      final emissions = <TokenPair?>[];
      final sub = store.changes.listen(emissions.add);

      await store.clear(); // real signed-in → signed-out: an event
      await store.clear(); // now a no-op: silent
      await Future<void>.delayed(Duration.zero);

      expect(emissions, [null]);
      await sub.cancel();
    });
  });
}
