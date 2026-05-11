import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import 'favorites_repository.dart';

/// Supabase-backed favorites store for authenticated users.
///
/// Reads and writes directly to the `public.favorites` table which is
/// protected by RLS so each user can only access their own rows.
/// Product snapshots are stored as JSONB so the Favorites screen renders
/// without an additional network round-trip to the products API.
class SupabaseFavoritesRepository implements FavoritesRepository {
  SupabaseFavoritesRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  final SupabaseClient _supabase;

  Set<String> _ids = {};
  final _controller = StreamController<Set<String>>.broadcast();

  String get _userId => _supabase.auth.currentUser!.id;

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _snapshot(Product p) => {
        'id': p.id,
        'slug': p.slug,
        'name': p.name.toJson(),
        'price': p.price,
        'old_price': p.oldPrice,
        'images': p.images,
        'primary_image': p.primaryImage,
        'category_slug': p.categorySlug,
        'stock': p.stock,
        'is_favorite': true,
      };

  void clearCache() {
    _ids = {};
    _controller.add(const <String>{});
  }

  // ── FavoritesRepository ───────────────────────────────────────────────────

  @override
  Set<String> get currentIds => Set.unmodifiable(_ids);

  @override
  bool isFavorite(String productId) => _ids.contains(productId);

  @override
  Stream<Set<String>> watchIds() => _controller.stream;

  @override
  Future<List<Product>> list() async {
    final rows = await _supabase
        .from('favorites')
        .select('product_id, product_snapshot')
        .eq('user_id', _userId);

    final products = <Product>[];
    final ids = <String>{};

    for (final row in rows) {
      final id = row['product_id'] as String?;
      if (id == null) continue;

      ids.add(id);

      final snapshot = row['product_snapshot'];
      if (snapshot is Map<String, dynamic>) {
        try {
          products.add(Product.fromJson({...snapshot, 'is_favorite': true}));
        } catch (_) {}
      }
    }

    _ids = ids;
    _controller.add(Set.unmodifiable(_ids));

    return products;
  }

  @override
  Future<void> toggle(Product product) async {
    if (_ids.contains(product.id)) {
      await remove(product.id);
    } else {
      await _supabase.from('favorites').upsert(
        {
          'user_id': _userId,
          'product_id': product.id,
          'product_snapshot': _snapshot(product),
        },
        onConflict: 'user_id,product_id',
      );
      _ids = {..._ids, product.id};
      _controller.add(Set.unmodifiable(_ids));
    }
  }

  @override
  Future<void> remove(String productId) async {
    await _supabase
        .from('favorites')
        .delete()
        .eq('user_id', _userId)
        .eq('product_id', productId);
    _ids = Set.from(_ids)..remove(productId);
    _controller.add(Set.unmodifiable(_ids));
  }
}
