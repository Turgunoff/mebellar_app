import 'dart:async';

import '../models/product.dart';
import '../repositories/favorites_repository.dart';
import 'mock_data.dart';

class MockFavoritesRepository implements FavoritesRepository {
  static const _delay = Duration(milliseconds: 180);

  final _controller = StreamController<Set<String>>.broadcast();
  final Set<String> _ids = <String>{};

  @override
  Set<String> get currentIds => Set.unmodifiable(_ids);

  @override
  bool isFavorite(String productId) => _ids.contains(productId);

  @override
  Stream<Set<String>> watchIds() => _controller.stream;

  @override
  Future<List<Product>> list() async {
    await Future<void>.delayed(_delay);
    final favs = MockData.products.where((p) => _ids.contains(p.id)).toList();
    return [
      for (final p in favs) p.copyWith(isFavorite: true),
    ];
  }

  @override
  Future<void> toggle(Product product) async {
    await Future<void>.delayed(_delay);
    if (_ids.contains(product.id)) {
      _ids.remove(product.id);
    } else {
      _ids.add(product.id);
    }
    _controller.add(Set.unmodifiable(_ids));
  }

  @override
  Future<void> remove(String productId) async {
    await Future<void>.delayed(_delay);
    _ids.remove(productId);
    _controller.add(Set.unmodifiable(_ids));
  }
}
