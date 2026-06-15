import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/shared/models/multilingual_text.dart';
import 'package:woody_app/shared/models/product.dart';
import 'package:woody_app/shared/repositories/hive_favorites_repository.dart';

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

Product _product(String id, {String name = 'Sofa', num price = 100}) => Product(
  id: id,
  slug: id,
  name: MultilingualText(uz: name),
  price: price,
);

void main() {
  group('HiveFavoritesRepository', () {
    test('toggle adds then removes', () async {
      final repo = HiveFavoritesRepository(box: _box());
      addTearDown(repo.dispose);
      await repo.toggle(_product('p1'));
      expect(repo.currentIds, {'p1'});
      expect(repo.isFavorite('p1'), isTrue);
      await repo.toggle(_product('p1'));
      expect(repo.currentIds, isEmpty);
    });

    test('persists and reloads across instances', () async {
      final store = <dynamic, dynamic>{};
      final repo = HiveFavoritesRepository(box: _box(store));
      await repo.toggle(_product('p1', name: 'Bed', price: 500));

      final reloaded = HiveFavoritesRepository(box: _box(store));
      expect(reloaded.currentIds, {'p1'});
      final product = (await reloaded.list()).single;
      expect(product.name.get('uz'), 'Bed');
      expect(product.price, 500);
    });

    test('parses Hive dynamic-typed maps without dropping the snapshot', () {
      // Real Hive hands back Map<dynamic, dynamic>, including the nested `name`
      // map; the snapshot must survive the deep-cast.
      final store = <dynamic, dynamic>{
        'items': [
          <dynamic, dynamic>{
            'id': 'p1',
            'slug': 'p1',
            'name': <dynamic, dynamic>{'uz': 'Sofa'},
            'price': 500,
            'images': <dynamic>[],
            'is_favorite': true,
          },
        ],
      };
      final repo = HiveFavoritesRepository(box: _box(store));
      expect(repo.currentIds, {'p1'});
      expect(repo.isFavorite('p1'), isTrue);
    });

    test('remove and clear', () async {
      final repo = HiveFavoritesRepository(box: _box());
      addTearDown(repo.dispose);
      await repo.toggle(_product('p1'));
      await repo.toggle(_product('p2'));
      await repo.remove('p1');
      expect(repo.currentIds, {'p2'});
      await repo.clear();
      expect(repo.currentIds, isEmpty);
    });

    test('watchIds emits the latest set on every change', () async {
      final repo = HiveFavoritesRepository(box: _box());
      final emissions = <int>[];
      final sub = repo.watchIds().listen((ids) => emissions.add(ids.length));
      await repo.toggle(_product('p1'));
      await repo.toggle(_product('p2'));
      await repo.remove('p1');
      await pumpEventQueue();
      await sub.cancel();
      expect(emissions, [1, 2, 1]);
    });
  });
}
