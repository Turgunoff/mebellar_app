import '../models/paginated.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import 'mock_data.dart';

class MockProductRepository implements ProductRepository {
  static const _delay = Duration(milliseconds: 350);

  @override
  Future<Paginated<Product>> list({
    ProductFilter filter = const ProductFilter(),
    int page = 1,
    int perPage = 20,
  }) async {
    await Future<void>.delayed(_delay);
    var items = List<Product>.from(MockData.products);

    if (filter.categorySlug != null) {
      final slug = filter.categorySlug!;
      // Match the leaf slug or any descendant of a parent category.
      final descendantSlugs = _descendants(slug);
      items = items
          .where((p) =>
              p.categorySlug == slug ||
              (p.categorySlug != null &&
                  descendantSlugs.contains(p.categorySlug)))
          .toList();
    }

    if (filter.shopSlug != null) {
      items = items.where((p) => p.shop?.slug == filter.shopSlug).toList();
    }

    if (filter.search != null && filter.search!.isNotEmpty) {
      final q = filter.search!.toLowerCase();
      items = items
          .where((p) =>
              p.name.uz?.toLowerCase().contains(q) == true ||
              p.name.ru?.toLowerCase().contains(q) == true ||
              p.name.en?.toLowerCase().contains(q) == true ||
              p.slug.toLowerCase().contains(q))
          .toList();
    }

    if (filter.minPrice != null) {
      items = items.where((p) => p.price >= filter.minPrice!).toList();
    }
    if (filter.maxPrice != null) {
      items = items.where((p) => p.price <= filter.maxPrice!).toList();
    }

    if (filter.featured == true) {
      items = items.where((p) => p.isOnSale).toList();
    }

    switch (filter.sort) {
      case ProductSort.priceAsc:
        items.sort((a, b) => a.price.compareTo(b.price));
      case ProductSort.priceDesc:
        items.sort((a, b) => b.price.compareTo(a.price));
      case ProductSort.popular:
        items.sort((a, b) => b.stock.compareTo(a.stock));
      case ProductSort.createdAt:
        // Mock data is already in insertion order — leave as-is.
        break;
    }

    final total = items.length;
    final start = (page - 1) * perPage;
    final end = (start + perPage).clamp(0, total);
    final pageItems = start >= total ? <Product>[] : items.sublist(start, end);

    return Paginated(
      items: pageItems,
      page: page,
      perPage: perPage,
      total: total,
      hasNext: end < total,
    );
  }

  @override
  Future<Product> getBySlug(String slug) async {
    await Future<void>.delayed(_delay);
    final found = MockData.products.where((p) => p.slug == slug).firstOrNull;
    if (found == null) {
      throw StateError('Product not found: $slug');
    }
    return found;
  }

  @override
  Future<Paginated<Product>> search(String query, {int page = 1}) {
    return list(filter: ProductFilter(search: query), page: page);
  }

  Set<String> _descendants(String parentSlug) {
    final cat = MockData.categoryBySlug(parentSlug);
    if (cat == null) return const {};
    final out = <String>{};
    void walk(category) {
      out.add(category.slug as String);
      for (final ch in category.children) {
        walk(ch);
      }
    }
    for (final ch in cat.children) {
      walk(ch);
    }
    return out;
  }
}
