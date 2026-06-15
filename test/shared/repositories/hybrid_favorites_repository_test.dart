import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/shared/models/multilingual_text.dart';
import 'package:woody_app/shared/models/product.dart';
import 'package:woody_app/shared/repositories/hive_favorites_repository.dart';
import 'package:woody_app/shared/repositories/hybrid_favorites_repository.dart';

class _MockBox extends Mock implements Box {}

Box _box() {
  final backing = <dynamic, dynamic>{};
  final box = _MockBox();
  when(
    () => box.get(any()),
  ).thenAnswer((i) => backing[i.positionalArguments.first]);
  when(() => box.put(any<dynamic>(), any<dynamic>())).thenAnswer((i) async {
    backing[i.positionalArguments[0]] = i.positionalArguments[1];
  });
  return box;
}

Product _product(String id) =>
    Product(id: id, slug: id, name: MultilingualText(uz: 'P$id'), price: 100);

void main() {
  group('HybridFavoritesRepository', () {
    test('guest toggles route to the local store, not the server', () async {
      final auth = StreamController<bool>.broadcast();
      final local = HiveFavoritesRepository(box: _box());
      final remote = HiveFavoritesRepository(box: _box());
      final hybrid = HybridFavoritesRepository(
        remote: remote,
        local: local,
        isSignedIn: () => false,
        authChanges: auth.stream,
      );
      addTearDown(hybrid.dispose);

      await hybrid.toggle(_product('p1'));
      await hybrid.toggle(_product('p2'));

      expect(local.currentIds, {'p1', 'p2'});
      expect(remote.currentIds, isEmpty);
      expect(hybrid.currentIds, {'p1', 'p2'}); // active = local
    });

    test('login unions the local list into the server, then empties it', () async {
      var signedIn = false;
      final auth = StreamController<bool>.broadcast();
      final local = HiveFavoritesRepository(box: _box());
      final remote = HiveFavoritesRepository(box: _box());
      final hybrid = HybridFavoritesRepository(
        remote: remote,
        local: local,
        isSignedIn: () => signedIn,
        authChanges: auth.stream,
      );
      addTearDown(hybrid.dispose);

      await hybrid.toggle(_product('p1'));
      await hybrid.toggle(_product('p2'));

      signedIn = true;
      auth.add(true);
      await pumpEventQueue(times: 50);

      expect(remote.currentIds, {'p1', 'p2'});
      expect(local.currentIds, isEmpty);
      expect(hybrid.currentIds, {'p1', 'p2'}); // active = remote now
    });

    test('merge is a union — an already-favorited product is NOT toggled off', () async {
      var signedIn = false;
      final auth = StreamController<bool>.broadcast();
      final local = HiveFavoritesRepository(box: _box());
      final remote = HiveFavoritesRepository(box: _box());
      // p1 is already favorited on the account before login.
      await remote.toggle(_product('p1'));

      final hybrid = HybridFavoritesRepository(
        remote: remote,
        local: local,
        isSignedIn: () => signedIn,
        authChanges: auth.stream,
      );
      addTearDown(hybrid.dispose);

      // Guest favorited p1 (dup) and p2 (new) locally.
      await hybrid.toggle(_product('p1'));
      await hybrid.toggle(_product('p2'));

      signedIn = true;
      auth.add(true);
      await pumpEventQueue(times: 50);

      // p1 survives (not removed by a blind toggle), p2 added.
      expect(remote.currentIds, {'p1', 'p2'});
      expect(local.currentIds, isEmpty);
    });

    test('sessionChanges fires only after the merge settles', () async {
      var signedIn = false;
      final auth = StreamController<bool>.broadcast();
      final local = HiveFavoritesRepository(box: _box());
      final remote = HiveFavoritesRepository(box: _box());
      final hybrid = HybridFavoritesRepository(
        remote: remote,
        local: local,
        isSignedIn: () => signedIn,
        authChanges: auth.stream,
      );
      addTearDown(hybrid.dispose);

      final emitted = <bool>[];
      final sub = hybrid.sessionChanges.listen(emitted.add);

      await hybrid.toggle(_product('p1'));
      signedIn = true;
      auth.add(true);
      await pumpEventQueue(times: 50);

      expect(emitted, [true]);
      // By the time the signal fires, the merge has already run.
      expect(remote.currentIds, {'p1'});
      await sub.cancel();
    });

    test('toggles route to the server when already signed in', () async {
      final auth = StreamController<bool>.broadcast();
      final local = HiveFavoritesRepository(box: _box());
      final remote = HiveFavoritesRepository(box: _box());
      final hybrid = HybridFavoritesRepository(
        remote: remote,
        local: local,
        isSignedIn: () => true,
        authChanges: auth.stream,
      );
      addTearDown(hybrid.dispose);

      await hybrid.toggle(_product('p1'));

      expect(remote.currentIds, {'p1'});
      expect(local.currentIds, isEmpty);
    });
  });
}
