
import '../models/product.dart';

abstract class FavoritesRepository {
  Stream<Set<String>> watchIds();
  Set<String> get currentIds;
  bool isFavorite(String productId);

  Future<List<Product>> list();
  Future<void> toggle(Product product);
  Future<void> remove(String productId);
}
