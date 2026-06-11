import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/models/multilingual_text.dart';
import 'package:woody_app/shared/models/product.dart';

/// The favorites snapshots come back from GET /favorites with `name`
/// rewritten to a plain localised STRING by the backend's live-name splice;
/// snapshots of deleted products keep the original `{uz,ru,en}` map. The
/// parser must accept both — a hard map cast here once silently emptied the
/// whole favorites tab.
void main() {
  group('Product.fromJson snapshot tolerance', () {
    test('accepts a plain string name (live-spliced snapshot)', () {
      final p = Product.fromJson(const {
        'id': 'p1',
        'name': "NESMA OQ yotoq to'plami",
        'price': 450,
        'images': ['https://cdn.example/img.jpg'],
      });
      expect(p.name.get('uz'), "NESMA OQ yotoq to'plami");
      expect(p.name.get('ru'), "NESMA OQ yotoq to'plami");
      expect(p.price, 450);
    });

    test('still accepts the canonical {uz,ru,en} map name', () {
      final p = Product.fromJson(const {
        'id': 'p1',
        'name': {'uz': 'Divan', 'ru': 'Диван'},
        'price': 100,
      });
      expect(p.name.get('uz'), 'Divan');
      expect(p.name.get('ru'), 'Диван');
    });

    test('missing name yields an empty multilingual text, not a throw', () {
      final p = Product.fromJson(const {'id': 'p1', 'price': 1});
      expect(p.name.get('uz'), '');
    });
  });

  group('MultilingualText.fromDynamic', () {
    test('mirrors a string into every language slot', () {
      final t = MultilingualText.fromDynamic('Stol');
      expect(t.uz, 'Stol');
      expect(t.ru, 'Stol');
      expect(t.en, 'Stol');
    });

    test('delegates a map to fromJson', () {
      final t = MultilingualText.fromDynamic(const {'uz': 'Stol'});
      expect(t.uz, 'Stol');
      expect(t.ru, isNull);
    });

    test('null and unexpected shapes degrade to empty', () {
      expect(MultilingualText.fromDynamic(null).get('uz'), '');
      expect(MultilingualText.fromDynamic(42).get('uz'), '');
    });
  });
}
