import '../../../../core/network/woody_api_client.dart';
import '../../../../shared/models/attribute_definition.dart';
import '../../../../shared/models/attribute_option.dart';

/// Loads the dynamic attribute schema for the (category, subcategory) pair
/// the seller is editing. Abstract because the cubit only needs the merged
/// list of definitions — keeping the SDK-bound implementation behind an
/// interface keeps the seam unit-testable.
abstract class AttributesRepository {
  /// Returns category-level + (optional) subcategory-level definitions,
  /// already merged and sorted. When [subcategoryId] is null only the
  /// category-scoped rows are returned.
  Future<List<AttributeDefinition>> loadForCategory({
    required String categoryId,
    String? subcategoryId,
  });
}

/// Pure-Dart merger used by [WoodyAttributesRepository] and by tests. Kept
/// as a free function so it can be exercised without a backend mock.
///
/// Merge rules:
///   * Category-scoped definitions come first; subcategory-scoped follow.
///   * On `key` collision, the subcategory definition wins — a category-wide
///     `width_cm` can be overridden by a subcategory-specific one (e.g. with
///     a different `is_required` or `unit`).
///   * Within each scope, ties on `key` are resolved by `sort_order` ascending
///     then `id` for determinism.
List<AttributeDefinition> mergeAttributeDefinitions({
  required List<AttributeDefinition> categoryDefs,
  required List<AttributeDefinition> subcategoryDefs,
}) {
  final byKey = <String, AttributeDefinition>{};
  for (final def in categoryDefs) {
    byKey[def.key] = def;
  }
  for (final def in subcategoryDefs) {
    byKey[def.key] = def;
  }
  final merged = byKey.values.toList()
    ..sort((a, b) {
      // Subcategory-scoped attrs sort AFTER category-scoped ones at the same
      // `sort_order`, so the form lays out the more-specific fields below
      // the broader ones.
      final scopeCmp =
          (a.isSubcategoryScoped ? 1 : 0) - (b.isSubcategoryScoped ? 1 : 0);
      if (scopeCmp != 0) return scopeCmp;
      final orderCmp = a.sortOrder.compareTo(b.sortOrder);
      if (orderCmp != 0) return orderCmp;
      return a.id.compareTo(b.id);
    });
  return List.unmodifiable(merged);
}

class WoodyAttributesRepository implements AttributesRepository {
  WoodyAttributesRepository({required WoodyApiClient api}) : _api = api;

  final WoodyApiClient _api;

  @override
  Future<List<AttributeDefinition>> loadForCategory({
    required String categoryId,
    String? subcategoryId,
  }) async {
    // The backend returns the category + subcategory definitions already
    // merged and sorted, with `options` nested under each definition. Options
    // carry no `attribute_id` over the wire (they're nested), so we stamp the
    // parent definition's id when building [AttributeOption].
    final rows = await _api.get<List<dynamic>>(
      '/seller/attributes',
      query: {
        'category_id': categoryId,
        if (subcategoryId != null) 'subcategory_id': subcategoryId,
      },
    );
    return rows.whereType<Map<String, dynamic>>().map((def) {
      final defId = def['id'] as String;
      final optsRaw = def['options'];
      final options = optsRaw is List
          ? optsRaw.whereType<Map<String, dynamic>>().map((o) {
              return AttributeOption(
                id: o['id'] as String,
                attributeId: defId,
                value: o['value'] as String,
                labelUz: o['label_uz'] as String? ?? '',
                labelRu: o['label_ru'] as String? ?? '',
                sortOrder: (o['sort_order'] as num?)?.toInt() ?? 0,
              );
            }).toList(growable: false)
          : const <AttributeOption>[];
      return AttributeDefinition.fromJson(def, options: options);
    }).toList(growable: false);
  }
}
