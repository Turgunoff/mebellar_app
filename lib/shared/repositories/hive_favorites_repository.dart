import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/product.dart';
import 'favorites_repository.dart';

/// Local, Hive-backed favorites for signed-out (guest) sessions.
///
/// Stores the same `product_snapshot` rows the backend favorites use, so the
/// guest list merges into the server account on login with a straight replay
/// (see `HybridFavoritesRepository`). The whole list lives under a single box
/// key — favorites are few, so rewriting on every toggle is cheaper than
/// per-row bookkeeping.
class HiveFavoritesRepository implements FavoritesRepository {
  HiveFavoritesRepository({required Box box}) : _box = box {
    _products = _load();
  }

  final Box _box;
  static const String _key = 'items';

  List<Product> _products = const [];
  final _controller = StreamController<Set<String>>.broadcast();

  List<Product> _load() {
    final raw = _box.get(_key);
    if (raw is! List) return const [];
    final products = <Product>[];
    for (final e in raw) {
      try {
        products.add(Product.fromJson(_asStringMap(e)));
      } catch (_) {
        // Skip a corrupt snapshot rather than blanking the whole tab.
      }
    }
    return List<Product>.unmodifiable(products);
  }

  Future<void> _save() async {
    await _box.put(_key, _products.map(_snapshot).toList());
  }

  /// Same shape as `WoodyFavoritesRepository._snapshot` so a guest→server
  /// replay POSTs an identical `product_snapshot`.
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

  Set<String> get _idSet => _products.map((p) => p.id).toSet();

  void _emit() => _controller.add(Set.unmodifiable(_idSet));

  @override
  Stream<Set<String>> watchIds() => _controller.stream;

  @override
  Set<String> get currentIds => Set.unmodifiable(_idSet);

  @override
  bool isFavorite(String productId) => _products.any((p) => p.id == productId);

  @override
  Future<List<Product>> list() async {
    _emit();
    return List<Product>.unmodifiable(_products);
  }

  @override
  Future<void> toggle(Product product) async {
    if (_products.any((p) => p.id == product.id)) {
      _products = _products
          .where((p) => p.id != product.id)
          .toList(growable: false);
    } else {
      _products = [..._products, product.copyWith(isFavorite: true)];
    }
    await _save();
    _emit();
  }

  @override
  Future<void> remove(String productId) async {
    _products = _products
        .where((p) => p.id != productId)
        .toList(growable: false);
    await _save();
    _emit();
  }

  /// Empties the guest list — called after a successful merge into the server
  /// account. Not part of [FavoritesRepository]; the hybrid holds this repo by
  /// its concrete type.
  Future<void> clear() async {
    _products = const [];
    await _save();
    _emit();
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Hive returns nested maps as `Map<dynamic, dynamic>`; deep-cast them to
/// `Map<String, dynamic>` so `Product.fromJson`'s typed checks match instead
/// of silently dropping the row.
Map<String, dynamic> _asStringMap(Object? raw) {
  if (raw is! Map) return const <String, dynamic>{};
  return raw.map(
    (k, v) => MapEntry(k.toString(), v is Map ? _asStringMap(v) : v),
  );
}
