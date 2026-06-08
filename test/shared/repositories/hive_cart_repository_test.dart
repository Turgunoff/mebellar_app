import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/shared/models/product_model.dart';
import 'package:woody_app/shared/repositories/hive_cart_repository.dart';

class _MockBox extends Mock implements Box {}

/// An in-memory [Box] backed by [store], so a second repository built on the
/// same map sees what the first persisted (round-trip).
Box _box([Map<dynamic, dynamic>? store]) {
  final backing = store ?? <dynamic, dynamic>{};
  final box = _MockBox();
  when(
    () => box.get(any()),
  ).thenAnswer((i) => backing[i.positionalArguments.first]);
  when(() => box.put(any<dynamic>(), any<dynamic>())).thenAnswer((i) async {
    backing[i.positionalArguments[0]] = i.positionalArguments[1];
  });
  return box;
}

ProductModel _product(String id, {String name = 'P', double price = 100}) =>
    ProductModel(
      id: id,
      categoryId: 'c',
      name: name,
      price: price,
      images: const [],
      stock: 1,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('HiveCartRepository', () {
    test('adding the same product increments its quantity', () async {
      final repo = HiveCartRepository(box: _box());
      await repo.addProduct(_product('p1'), quantity: 2);
      await repo.addProduct(_product('p1'), quantity: 3);
      expect(repo.currentItems, hasLength(1));
      expect(repo.currentItems.single.quantity, 5);
    });

    test('persists and reloads across instances', () async {
      final store = <dynamic, dynamic>{};
      final repo = HiveCartRepository(box: _box(store));
      await repo.addProduct(
        _product('p1', name: 'Bed', price: 100),
        quantity: 2,
      );

      final reloaded = HiveCartRepository(box: _box(store));
      expect(reloaded.currentItems, hasLength(1));
      expect(reloaded.currentItems.single.productId, 'p1');
      expect(reloaded.currentItems.single.productName, 'Bed');
      expect(reloaded.currentItems.single.quantity, 2);
    });

    test('parses Hive dynamic-typed maps without dropping the snapshot', () {
      // Real Hive hands back Map<dynamic, dynamic>; the snapshot must survive.
      final store = <dynamic, dynamic>{
        'items': [
          <dynamic, dynamic>{
            'id': 'p1',
            'product_id': 'p1',
            'quantity': 4,
            'product_snapshot': <dynamic, dynamic>{
              'id': 'p1',
              'name': 'Sofa',
              'image': '',
              'price': 500,
              'color': 'white',
            },
            'created_at': '2026-01-01T00:00:00.000',
          },
        ],
      };
      final repo = HiveCartRepository(box: _box(store));
      final item = repo.currentItems.single;
      expect(item.productName, 'Sofa');
      expect(item.productPrice, 500);
      expect(item.selectedColor, 'white');
      expect(item.quantity, 4);
    });

    test('remove and clear', () async {
      final repo = HiveCartRepository(box: _box());
      await repo.addProduct(_product('p1'));
      await repo.addProduct(_product('p2'));
      await repo.removeProduct('p1');
      expect(repo.currentItems.single.productId, 'p2');
      await repo.clear();
      expect(repo.currentItems, isEmpty);
    });

    test('watchItems emits the latest snapshot on every change', () async {
      final repo = HiveCartRepository(box: _box());
      final emissions = <int>[];
      final sub = repo.watchItems().listen(
        (items) => emissions.add(items.length),
      );
      await repo.addProduct(_product('p1'));
      await repo.addProduct(_product('p2'));
      await repo.removeProduct('p1');
      await pumpEventQueue();
      await sub.cancel();
      expect(emissions, [1, 2, 1]);
    });
  });
}
