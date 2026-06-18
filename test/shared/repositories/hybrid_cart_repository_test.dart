import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/api_error.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';
import 'package:woody_app/shared/models/product_model.dart';
import 'package:woody_app/shared/repositories/cart_repository.dart';
import 'package:woody_app/shared/repositories/hive_cart_repository.dart';
import 'package:woody_app/shared/repositories/hybrid_cart_repository.dart';

class _MockBox extends Mock implements Box {}

class _MockRemote extends Mock implements CartRepository {}

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
  setUpAll(() => registerFallbackValue(_product('fallback')));

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

    // CART-01: a transient failure must keep its line locally to retry, while a
    // permanent rejection drops it — and the merge reports both counts so the
    // UI can tell the user about lost items.
    test(
      'login merge keeps transient failures, drops permanent ones, reports counts',
      () async {
        var signedIn = false;
        final auth = StreamController<bool>.broadcast();
        final local = HiveCartRepository(box: _box());
        final remote = _MockRemote();
        when(
          () => remote.watchItems(),
        ).thenAnswer((_) => const Stream<List<CartItemModel>>.empty());
        when(
          () => remote.fetchItems(),
        ).thenAnswer((_) async => const <CartItemModel>[]);
        when(
          () => remote.addProduct(
            any(),
            quantity: any(named: 'quantity'),
            selectedColor: any(named: 'selectedColor'),
          ),
        ).thenAnswer((inv) async {
          final p = inv.positionalArguments.first as ProductModel;
          if (p.id == 'gone') throw ApiError(status: 404, code: 'not_found');
          if (p.id == 'flaky') throw ApiError(status: 503, code: 'unavailable');
          // 'p1' merges fine.
        });

        final hybrid = HybridCartRepository(
          remote: remote,
          local: local,
          isSignedIn: () => signedIn,
          authChanges: auth.stream,
        );
        addTearDown(hybrid.dispose);

        await local.addProduct(_product('p1'));
        await local.addProduct(_product('gone'));
        await local.addProduct(_product('flaky'));

        final reported = hybrid.mergeEvents.first;

        signedIn = true;
        auth.add(true);
        await pumpEventQueue(times: 50);

        // Only the transient 503 line survives locally for the next merge.
        expect(local.currentItems.map((e) => e.productId), ['flaky']);

        final result = await reported;
        expect(result.merged, 1); // p1
        expect(result.dropped, 1); // gone (404)
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
