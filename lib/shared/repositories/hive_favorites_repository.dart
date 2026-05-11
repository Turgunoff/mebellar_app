import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/product.dart';
import 'favorites_repository.dart';

/// Local Hive-backed favorites store for unauthenticated (guest) users.
///
/// Products are persisted as compact JSON snapshots so the Favorites screen
/// works without a network connection. The box is cleared automatically after
/// a successful sync to Supabase on login.
class HiveFavoritesRepository implements FavoritesRepository {
  HiveFavoritesRepository(this._box);

  final Box _box;

  static const String _storeKey = 'guest_favorites';

  final _controller = StreamController<Set<String>>.broadcast();

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Reads `{productId: jsonString}` map from Hive, returning an empty map
  /// if the key does not exist or the stored value has an unexpected type.
  Map<String, String> _readStore() {
    final raw = _box.get(_storeKey);
    if (raw is Map) {
      return Map.fromEntries(
        raw.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
      );
    }
    return {};
  }

  /// Minimal product snapshot that can be round-tripped via [Product.fromJson].
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

  // ── Public API ────────────────────────────────────────────────────────────

  /// Removes all guest favorites from Hive. Called after sync-to-Supabase.
  Future<void> clear() async {
    await _box.delete(_storeKey);
    _controller.add(const <String>{});
  }

  // ── FavoritesRepository ───────────────────────────────────────────────────

  @override
  Set<String> get currentIds => _readStore().keys.toSet();

  @override
  bool isFavorite(String productId) => _readStore().containsKey(productId);

  @override
  Stream<Set<String>> watchIds() => _controller.stream;

  @override
  Future<List<Product>> list() async {
    return _readStore().values
        .map((jsonStr) {
          try {
            final raw = jsonDecode(jsonStr) as Map<String, dynamic>;
            return Product.fromJson(raw);
          } catch (_) {
            return null;
          }
        })
        .whereType<Product>()
        .toList();
  }

  @override
  Future<void> toggle(Product product) async {
    final store = _readStore();
    if (store.containsKey(product.id)) {
      store.remove(product.id);
    } else {
      store[product.id] = jsonEncode(_snapshot(product));
    }
    await _box.put(_storeKey, store);
    _controller.add(store.keys.toSet());
  }

  @override
  Future<void> remove(String productId) async {
    final store = _readStore();
    store.remove(productId);
    await _box.put(_storeKey, store);
    _controller.add(store.keys.toSet());
  }
}
