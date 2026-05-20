import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Pure-Dart merger used by [SupabaseAttributesRepository] and by tests. Kept
/// as a free function so it can be exercised without a Supabase mock.
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

class SupabaseAttributesRepository implements AttributesRepository {
  SupabaseAttributesRepository({required SupabaseClient supabase})
      : _client = supabase;

  final SupabaseClient _client;

  @override
  Future<List<AttributeDefinition>> loadForCategory({
    required String categoryId,
    String? subcategoryId,
  }) async {
    // Pull category-scoped and (when requested) subcategory-scoped rows in
    // parallel. Options are fetched in a single second round-trip so the
    // schema render is a 2-query operation regardless of attribute count.
    final defsFuture = Future.wait<List<Map<String, dynamic>>>([
      _fetchRows(
          _client.from('attribute_definitions').select(
                'id, category_id, subcategory_id, key, label_uz, label_ru, '
                'data_type, unit, is_required, sort_order',
              ),
          'category_id',
          categoryId),
      if (subcategoryId != null)
        _fetchRows(
            _client.from('attribute_definitions').select(
                  'id, category_id, subcategory_id, key, label_uz, label_ru, '
                  'data_type, unit, is_required, sort_order',
                ),
            'subcategory_id',
            subcategoryId)
      else
        Future.value(const <Map<String, dynamic>>[]),
    ]);
    final defsResults = await defsFuture;
    final allDefRows = [...defsResults[0], ...defsResults[1]];
    if (allDefRows.isEmpty) return const [];

    final defIds = [for (final r in allDefRows) r['id'] as String];
    final optionRows = await _client
        .from('attribute_options')
        .select(
            'id, attribute_id, value, label_uz, label_ru, sort_order')
        .inFilter('attribute_id', defIds)
        .order('sort_order', ascending: true);

    final optionsByDef = <String, List<AttributeOption>>{};
    for (final row in (optionRows as List).whereType<Map<String, dynamic>>()) {
      final opt = AttributeOption.fromJson(row);
      optionsByDef.putIfAbsent(opt.attributeId, () => []).add(opt);
    }

    AttributeDefinition build(Map<String, dynamic> row) {
      return AttributeDefinition.fromJson(
        row,
        options: optionsByDef[row['id'] as String] ?? const [],
      );
    }

    final categoryDefs = [for (final r in defsResults[0]) build(r)];
    final subcategoryDefs = [for (final r in defsResults[1]) build(r)];
    return mergeAttributeDefinitions(
      categoryDefs: categoryDefs,
      subcategoryDefs: subcategoryDefs,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRows(
    PostgrestFilterBuilder<dynamic> base,
    String column,
    String value,
  ) async {
    final rows = await base.eq(column, value).order('sort_order', ascending: true);
    return (rows as List).whereType<Map<String, dynamic>>().toList(growable: false);
  }
}
