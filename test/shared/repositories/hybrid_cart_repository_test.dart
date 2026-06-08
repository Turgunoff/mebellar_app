import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/shared/models/product_model.dart';
import 'package:woody_app/shared/repositories/hive_cart_repository.dart';
import 'package:woody_app/shared/repositories/hybrid_cart_repository.dart';

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

ProductModel _product(String id) => ProductModel(
  id: id,
  categoryId: 'c',
  name: 'P$id',
  price: 100,
  images: const [],
  stock: 1,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('HybridCartRepository', () {
    test('guest adds route to the local cart, not the server', () async {
      final auth = StreamController<bool>.broadcast();
      final local = HiveCartRepository(box: _box());
      final remote = HiveCartRepository(box: _box());
      final hybrid = HybridCartRepository(
        remote: remote,
        local: local,
        isSignedIn: () => false,
        authChanges: auth.stream,
      );
      addTearDown(hybrid.dispose);

      await hybrid.addProduct(_product('p1'), quantity: 2);
      await hybrid.addProduct(_product('p2'));

      expect(local.currentItems, hasLength(2));
      expect(remote.currentItems, isEmpty);
      expect(hybrid.currentItems, hasLength(2)); // active = local
    });

    test(
      'login merges the local cart into the server, then empties it',
      () async {
        var signedIn = false;
        final auth = StreamController<bool>.broadcast();
        final local = HiveCartRepository(box: _box());
        final remote = HiveCartRepository(box: _box());
        final hybrid = HybridCartRepository(
          remote: remote,
          local: local,
          isSignedIn: () => signedIn,
          authChanges: auth.stream,
        );
        addTearDown(hybrid.dispose);

        await hybrid.addProduct(_product('p1'), quantity: 2);
        await hybrid.addProduct(_product('p2'));

        // Sign in: the token flips first, then the change is broadcast.
        signedIn = true;
        auth.add(true);
        await pumpEventQueue(times: 50);

        expect(remote.currentItems.map((e) => e.productId).toSet(), {
          'p1',
          'p2',
        });
        expect(local.currentItems, isEmpty);
        expect(hybrid.currentItems, hasLength(2)); // active = remote now
      },
    );

    test('adds route to the server when already signed in', () async {
      final auth = StreamController<bool>.broadcast();
      final local = HiveCartRepository(box: _box());
      final remote = HiveCartRepository(box: _box());
      final hybrid = HybridCartRepository(
        remote: remote,
        local: local,
        isSignedIn: () => true,
        authChanges: auth.stream,
      );
      addTearDown(hybrid.dispose);

      await hybrid.addProduct(_product('p1'));

      expect(remote.currentItems, hasLength(1));
      expect(local.currentItems, isEmpty);
    });
  });
}
