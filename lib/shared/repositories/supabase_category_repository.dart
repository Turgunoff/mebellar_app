import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_model.dart';

abstract class CategoryDataSource {
  Future<List<CategoryModel>> list();
}

/// Fetches categories with their nested subcategories from Supabase.
/// Ordered by `sort_order` ascending.
class SupabaseCategoryRepository implements CategoryDataSource {
  SupabaseCategoryRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  final SupabaseClient _supabase;

  @override
  Future<List<CategoryModel>> list() async {
    final data = await _supabase
        .from('categories')
        .select('*, subcategories(*)')
        .order('sort_order', ascending: true);

    return (data as List)
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList(growable: false);
  }
}

/// In-memory fallback used when Supabase is unavailable (e.g. offline or
/// test environment). Mirrors the Unsplash images from the categories table.
class MockCategoryDataSource implements CategoryDataSource {
  static const _delay = Duration(milliseconds: 350);

  @override
  Future<List<CategoryModel>> list() async {
    await Future<void>.delayed(_delay);
    return const [
      CategoryModel(
        id: 'mock-1',
        name: 'Sofas & Armchairs',
        subtitle: 'Living Room',
        imageUrl:
            'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=1400&q=80',
        sortOrder: 1,
        subcategories: [
          SubcategoryModel(id: 's1', categoryId: 'mock-1', name: 'Corner Sofas'),
          SubcategoryModel(id: 's2', categoryId: 'mock-1', name: '3-Seater Sofas'),
          SubcategoryModel(id: 's3', categoryId: 'mock-1', name: 'Armchairs'),
          SubcategoryModel(id: 's4', categoryId: 'mock-1', name: 'Sofa Beds'),
        ],
      ),
      CategoryModel(
        id: 'mock-2',
        name: 'Tables & Desks',
        subtitle: 'Dining & Work',
        imageUrl:
            'https://images.unsplash.com/photo-1449247709967-d4461a6a6103?w=1400&q=80',
        sortOrder: 2,
        subcategories: [
          SubcategoryModel(id: 's5', categoryId: 'mock-2', name: 'Dining Tables'),
          SubcategoryModel(id: 's6', categoryId: 'mock-2', name: 'Coffee Tables'),
          SubcategoryModel(id: 's7', categoryId: 'mock-2', name: 'Study Desks'),
        ],
      ),
      CategoryModel(
        id: 'mock-3',
        name: 'Beds & Bedrooms',
        subtitle: 'Rest',
        imageUrl:
            'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=1400&q=80',
        sortOrder: 3,
        subcategories: [
          SubcategoryModel(id: 's8', categoryId: 'mock-3', name: 'Double Beds'),
          SubcategoryModel(id: 's9', categoryId: 'mock-3', name: 'Single Beds'),
        ],
      ),
      CategoryModel(
        id: 'mock-4',
        name: 'Chairs & Seating',
        subtitle: 'Lounge',
        imageUrl:
            'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?w=1400&q=80',
        sortOrder: 4,
      ),
      CategoryModel(
        id: 'mock-5',
        name: 'Lighting',
        subtitle: 'Ambience',
        imageUrl:
            'https://images.unsplash.com/photo-1513506003901-1e6a229e2d15?w=1400&q=80',
        sortOrder: 5,
      ),
      CategoryModel(
        id: 'mock-6',
        name: 'Storage & Wardrobes',
        subtitle: 'Organization',
        imageUrl:
            'https://images.unsplash.com/photo-1595428774223-ef52624120d2?w=1400&q=80',
        sortOrder: 6,
      ),
      CategoryModel(
        id: 'mock-7',
        name: 'Decor & Accents',
        subtitle: 'Finishing Touches',
        imageUrl:
            'https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=1400&q=80',
        sortOrder: 7,
      ),
      CategoryModel(
        id: 'mock-8',
        name: 'Outdoor Living',
        subtitle: 'Garden & Terrace',
        imageUrl:
            'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?w=1400&q=80',
        sortOrder: 8,
      ),
    ];
  }
}
