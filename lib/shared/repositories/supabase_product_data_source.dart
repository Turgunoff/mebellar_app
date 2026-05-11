import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supabase_product_model.dart';

abstract class SupabaseProductDataSource {
  Future<List<SupabaseProductModel>> listByCategory({
    required String categoryId,
    String? subcategoryId,
  });
  Future<List<SupabaseProductModel>> listBySubcategory({
    required String subcategoryId,
  });
  Future<SupabaseProductModel> getById(String id);

  /// Newest-first products across the catalog. Used by the Home screen's
  /// "Recommended for you" rail until we have a real recs engine.
  Future<List<SupabaseProductModel>> listAll({int limit = 10});

  /// Case-insensitive `ilike` over name + description. Returns newest-first.
  Future<List<SupabaseProductModel>> search(String query, {int limit = 30});
}

class SupabaseProductRepository implements SupabaseProductDataSource {
  SupabaseProductRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  final SupabaseClient _supabase;

  @override
  Future<List<SupabaseProductModel>> listByCategory({
    required String categoryId,
    String? subcategoryId,
  }) async {
    var query = _supabase
        .from('products')
        .select()
        .eq('category_id', categoryId);

    if (subcategoryId != null) {
      query = query.eq('subcategory_id', subcategoryId);
    }

    final data = await query.order('created_at', ascending: false);
    return data
        .map(SupabaseProductModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<SupabaseProductModel>> listBySubcategory({
    required String subcategoryId,
  }) async {
    final data = await _supabase
        .from('products')
        .select()
        .eq('subcategory_id', subcategoryId)
        .order('created_at', ascending: false);
    return data.map(SupabaseProductModel.fromJson).toList(growable: false);
  }

  @override
  Future<SupabaseProductModel> getById(String id) async {
    final data = await _supabase
        .from('products')
        .select()
        .eq('id', id)
        .single();
    return SupabaseProductModel.fromJson(data);
  }

  @override
  Future<List<SupabaseProductModel>> listAll({int limit = 10}) async {
    final data = await _supabase
        .from('products')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .whereType<Map<String, dynamic>>()
        .map(SupabaseProductModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<SupabaseProductModel>> search(
    String query, {
    int limit = 30,
  }) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    // Escape the % and _ wildcards so user input can't broaden the match.
    final escaped = term
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';
    final data = await _supabase
        .from('products')
        .select()
        .or('name.ilike.$pattern,description.ilike.$pattern')
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .whereType<Map<String, dynamic>>()
        .map(SupabaseProductModel.fromJson)
        .toList(growable: false);
  }
}

class MockSupabaseProductDataSource implements SupabaseProductDataSource {
  static const _delay = Duration(milliseconds: 400);

  static final List<SupabaseProductModel> _all = [
    SupabaseProductModel(
      id: 'prod-1',
      categoryId: 'mock-1',
      name: 'Velvet Corner Sofa',
      description:
          'A luxurious L-shaped velvet corner sofa with solid wood legs. '
          'Sink into supreme comfort with high-density foam cushions wrapped in premium velvet fabric.',
      price: 1299000,
      images: [
        'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=1400&q=80',
        'https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=1400&q=80',
      ],
      attributes: {
        'Color': 'Midnight Blue',
        'Material': 'Velvet',
        'Legs': 'Solid Oak',
        'Seats': '4–5',
        'Width': '280 cm',
      },
      stock: 12,
      createdAt: DateTime(2026, 1, 1),
    ),
    SupabaseProductModel(
      id: 'prod-2',
      categoryId: 'mock-1',
      name: 'Modern 3-Seat Sofa',
      description:
          'Timeless 3-seater sofa in light grey linen with tapered walnut legs. '
          'Designed for everyday comfort and lasting style.',
      price: 899000,
      images: [
        'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?w=1400&q=80',
      ],
      attributes: {
        'Color': 'Light Grey',
        'Material': 'Linen',
        'Legs': 'Walnut',
        'Seats': '3',
      },
      stock: 8,
      createdAt: DateTime(2026, 1, 2),
    ),
    SupabaseProductModel(
      id: 'prod-3',
      categoryId: 'mock-2',
      name: 'Oak Extendable Dining Table',
      description:
          'Handcrafted solid oak dining table that extends from 160 cm to 240 cm. '
          'Perfect for family dinners and entertaining guests.',
      price: 849000,
      images: [
        'https://images.unsplash.com/photo-1449247709967-d4461a6a6103?w=1400&q=80',
      ],
      attributes: {
        'Color': 'Natural Oak',
        'Material': 'Solid Oak',
        'Seats': '6–8',
        'Width': '160–240 cm',
      },
      stock: 7,
      createdAt: DateTime(2026, 1, 3),
    ),
    SupabaseProductModel(
      id: 'prod-4',
      categoryId: 'mock-3',
      name: 'Scandinavian Platform Bed',
      description:
          'Minimalist platform bed in white lacquered MDF with integrated headboard. '
          'Features under-bed storage drawers for a clutter-free bedroom.',
      price: 1099000,
      images: [
        'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=1400&q=80',
      ],
      attributes: {
        'Color': 'White',
        'Material': 'MDF',
        'Size': '160×200 cm',
        'Storage': '2 drawers',
      },
      stock: 5,
      createdAt: DateTime(2026, 1, 4),
    ),
  ];

  @override
  Future<List<SupabaseProductModel>> listByCategory({
    required String categoryId,
    String? subcategoryId,
  }) async {
    await Future<void>.delayed(_delay);
    return _all
        .where((p) =>
            p.categoryId == categoryId &&
            (subcategoryId == null || p.subcategoryId == subcategoryId))
        .toList(growable: false);
  }

  @override
  Future<List<SupabaseProductModel>> listBySubcategory({
    required String subcategoryId,
  }) async {
    await Future<void>.delayed(_delay);
    return _all
        .where((p) => p.subcategoryId == subcategoryId)
        .toList(growable: false);
  }

  @override
  Future<SupabaseProductModel> getById(String id) async {
    await Future<void>.delayed(_delay);
    return _all.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('Product not found: $id'),
    );
  }

  @override
  Future<List<SupabaseProductModel>> listAll({int limit = 10}) async {
    await Future<void>.delayed(_delay);
    final sorted = [..._all]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList(growable: false);
  }

  @override
  Future<List<SupabaseProductModel>> search(
    String query, {
    int limit = 30,
  }) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return const [];
    await Future<void>.delayed(_delay);
    return _all
        .where(
          (p) =>
              p.name.toLowerCase().contains(term) ||
              (p.description ?? '').toLowerCase().contains(term),
        )
        .take(limit)
        .toList(growable: false);
  }
}
