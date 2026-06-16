import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/products/data/ar_scan_components.dart';
import 'package:woody_app/shared/models/attribute_definition.dart';
import 'package:woody_app/shared/models/multilingual_text.dart';
import 'package:woody_app/shared/models/seller_product.dart';

AttributeDefinition _dim(String key, String labelUz, int sort) =>
    AttributeDefinition(
      id: key,
      categoryId: 'cat',
      subcategoryId: null,
      key: key,
      labelUz: labelUz,
      labelRu: labelUz,
      dataType: AttributeDataType.number,
      unit: 'sm',
      isRequired: false,
      sortOrder: sort,
    );

SellerProduct _product({
  Map<String, dynamic> attributes = const {},
  num? widthCm,
  num? heightCm,
  num? lengthCm,
}) =>
    SellerProduct(
      id: 'p1',
      name: const MultilingualText(uz: 'Divan', ru: 'Диван', en: 'Sofa'),
      description: const MultilingualText(),
      categorySlug: 'cat',
      price: 100,
      sku: 'SKU',
      images: const [],
      attributes: attributes,
      widthCm: widthCm,
      heightCm: heightCm,
      lengthCm: lengthCm,
      status: SellerProductStatus.approved,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('resolveArScanComponents — multi-piece set', () {
    final schema = [
      _dim('bed_length_cm', 'Krovat — uzunligi', 10),
      _dim('bed_height_cm', 'Krovat — balandligi', 11),
      _dim('bed_width_cm', 'Krovat — kengligi', 12),
      _dim('wardrobe_width_cm', 'Shkaf — kengligi', 20),
      _dim('wardrobe_height_cm', 'Shkaf — balandligi', 21),
      _dim('wardrobe_depth_cm', 'Shkaf — chuqurligi', 22),
    ];

    test('groups by piece, maps a bed length to the depth axis', () {
      final product = _product(attributes: {
        'bed_length_cm': 210,
        'bed_height_cm': 110,
        'bed_width_cm': 160,
        'wardrobe_width_cm': 200,
        'wardrobe_height_cm': 220,
        'wardrobe_depth_cm': 60,
      });

      final comps = resolveArScanComponents(schema: schema, product: product);

      expect(comps.map((c) => c.label), ['Krovat', 'Shkaf']);

      final bed = comps[0];
      expect(bed.heightCm, 110);
      expect(bed.widthCm, 160);
      // No bed depth → the length axis fills the backend's length_cm (= depth).
      expect(bed.lengthCm, 210);
      expect(bed.isComplete, isTrue);

      final wardrobe = comps[1];
      expect(wardrobe.heightCm, 220);
      expect(wardrobe.widthCm, 200);
      expect(wardrobe.lengthCm, 60); // real depth wins
      expect(wardrobe.isComplete, isTrue);
    });

    test('a piece missing an axis is listed but not complete', () {
      final product = _product(attributes: {
        // Bed without height — required by the backend, so not scannable.
        'bed_length_cm': 210,
        'bed_width_cm': 160,
        'wardrobe_width_cm': 200,
        'wardrobe_height_cm': 220,
        'wardrobe_depth_cm': 60,
      });

      final comps = resolveArScanComponents(schema: schema, product: product);
      expect(comps.length, 2);
      expect(comps[0].label, 'Krovat');
      expect(comps[0].isComplete, isFalse);
      expect(comps[0].summary, '160 × — × 210 sm');
      expect(comps[1].isComplete, isTrue);
    });

    test('skips pieces with no values at all', () {
      final product = _product(attributes: {
        'bed_length_cm': 210,
        'bed_height_cm': 110,
        'bed_width_cm': 160,
        // wardrobe_* entirely absent
      });
      final comps = resolveArScanComponents(schema: schema, product: product);
      expect(comps.map((c) => c.label), ['Krovat']);
    });
  });

  group('resolveArScanComponents — single product', () {
    test('builds one component from the typed columns', () {
      final product = _product(widthCm: 90, heightCm: 85, lengthCm: 200);
      final comps = resolveArScanComponents(schema: const [], product: product);
      expect(comps.length, 1);
      expect(comps.single.label, 'Divan');
      expect(comps.single.widthCm, 90);
      expect(comps.single.heightCm, 85);
      expect(comps.single.lengthCm, 200);
      expect(comps.single.isComplete, isTrue);
    });

    test('falls back to bare attributes, depth feeding the length axis', () {
      final product = _product(attributes: {
        'width_cm': 90,
        'height_cm': 85,
        'depth_cm': 95,
      });
      final comps = resolveArScanComponents(schema: const [], product: product);
      expect(comps.single.widthCm, 90);
      expect(comps.single.heightCm, 85);
      expect(comps.single.lengthCm, 95);
    });

    test('rounds and rejects non-positive values', () {
      final product = _product(attributes: {
        'width_cm': 90.4,
        'height_cm': 0,
        'depth_cm': '120,5',
      });
      final comps = resolveArScanComponents(schema: const [], product: product);
      expect(comps.single.widthCm, 90);
      expect(comps.single.heightCm, isNull); // 0 dropped
      expect(comps.single.lengthCm, 121); // "120,5" parsed + rounded
      expect(comps.single.isComplete, isFalse);
    });

    test('returns empty when the product has no dimension data', () {
      final comps =
          resolveArScanComponents(schema: const [], product: _product());
      expect(comps, isEmpty);
    });
  });
}
