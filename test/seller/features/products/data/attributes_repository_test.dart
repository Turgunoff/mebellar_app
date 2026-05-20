import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/products/data/attributes_repository.dart';
import 'package:woody_app/shared/models/attribute_definition.dart';

AttributeDefinition _def(
  String key, {
  String? categoryId,
  String? subcategoryId,
  int sortOrder = 10,
}) {
  return AttributeDefinition(
    id: 'def-$key-${subcategoryId ?? categoryId ?? ''}',
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    key: key,
    labelUz: key,
    labelRu: key,
    dataType: AttributeDataType.text,
    unit: null,
    isRequired: false,
    sortOrder: sortOrder,
  );
}

void main() {
  group('mergeAttributeDefinitions', () {
    test('returns empty list when both inputs are empty', () {
      final merged = mergeAttributeDefinitions(
        categoryDefs: const [],
        subcategoryDefs: const [],
      );
      expect(merged, isEmpty);
    });

    test('category-only definitions retain their relative sort order', () {
      final defs = [
        _def('width_cm', categoryId: 'cat-1', sortOrder: 30),
        _def('fabric_type', categoryId: 'cat-1', sortOrder: 10),
        _def('seats', categoryId: 'cat-1', sortOrder: 20),
      ];
      final merged = mergeAttributeDefinitions(
        categoryDefs: defs,
        subcategoryDefs: const [],
      );
      expect(
        merged.map((d) => d.key).toList(),
        ['fabric_type', 'seats', 'width_cm'],
      );
    });

    test('subcategory definitions sort below category ones with same order',
        () {
      final categoryDefs = [
        _def('width_cm', categoryId: 'cat-1', sortOrder: 10),
      ];
      final subcategoryDefs = [
        _def('corner_side', subcategoryId: 'sub-1', sortOrder: 10),
      ];
      final merged = mergeAttributeDefinitions(
        categoryDefs: categoryDefs,
        subcategoryDefs: subcategoryDefs,
      );
      expect(
        merged.map((d) => d.key).toList(),
        ['width_cm', 'corner_side'],
        reason: 'category-scoped attrs come first at equal sort_order',
      );
    });

    test('subcategory definition overrides a category one with the same key',
        () {
      final categoryDefs = [
        _def('width_cm', categoryId: 'cat-1', sortOrder: 10),
      ];
      final subcategoryDefs = [
        _def('width_cm', subcategoryId: 'sub-1', sortOrder: 50),
      ];
      final merged = mergeAttributeDefinitions(
        categoryDefs: categoryDefs,
        subcategoryDefs: subcategoryDefs,
      );
      expect(merged, hasLength(1),
          reason: 'collision must dedupe to a single row');
      expect(merged.first.isSubcategoryScoped, isTrue,
          reason: 'subcategory-scoped row wins');
    });

    test('mixed scopes interleave by sort_order within each scope', () {
      final categoryDefs = [
        _def('a', categoryId: 'cat-1', sortOrder: 20),
        _def('b', categoryId: 'cat-1', sortOrder: 10),
      ];
      final subcategoryDefs = [
        _def('c', subcategoryId: 'sub-1', sortOrder: 5),
        _def('d', subcategoryId: 'sub-1', sortOrder: 30),
      ];
      final merged = mergeAttributeDefinitions(
        categoryDefs: categoryDefs,
        subcategoryDefs: subcategoryDefs,
      );
      expect(
        merged.map((d) => d.key).toList(),
        ['b', 'a', 'c', 'd'],
      );
    });
  });
}
