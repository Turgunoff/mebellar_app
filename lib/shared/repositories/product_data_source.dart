import 'package:equatable/equatable.dart';

import '../models/product_model.dart';

/// Page size for the home feed's infinite scroll. The first page and every
/// subsequent [ProductDataSource.listFeed] fetch pull this many rows.
const int kHomeFeedPageSize = 15;

/// Page size for the per-category product list's infinite scroll. The first
/// page and every subsequent [ProductDataSource.listByCategory] fetch pull this
/// many rows — mirrors [kHomeFeedPageSize] so both feeds page identically.
const int kCategoryPageSize = 15;

/// Ordering strategies the home "Siz uchun tavsiya" feed can request. These map
/// to the backend `sort` values added for the curated feed — distinct from the
/// in-category [ProductSearchSort] facet so the feed's options (recommended /
/// popular / discount) don't leak into the filter sheet.
enum HomeFeedSort {
  /// Curated default — in-stock, then discounted, then most-ordered, then new.
  recommended,

  /// Highest all-time order volume first ("Eng ommabop").
  popular,

  /// Deepest discount first ("Chegirmalilar oldin").
  discount,

  /// Newest products first.
  newest,
}

/// One page of the catalog feed plus the catalog-wide [total], so the caller
/// can tell whether more pages remain (`offset + items.length < total`).
class ProductFeedPage extends Equatable {
  const ProductFeedPage({required this.items, required this.total});

  /// Empty page — the canonical "nothing here" result.
  static const empty = ProductFeedPage(items: [], total: 0);

  final List<ProductModel> items;
  final int total;

  @override
  List<Object?> get props => [items, total];
}

/// Ordering options accepted by [ProductDataSource.search]. The search
/// feature renders one of these by default and lets the user pick a different
/// one from the filter sheet. New sort options should land here (and in the
/// implementation `_applySort`) rather than as ad-hoc orderings on the call
/// site so every search path stays consistent.
enum ProductSearchSort {
  /// Default — newest products first.
  newest,

  /// Cheapest first using `effective_price` so discounts are honoured.
  priceAsc,

  /// Most expensive first.
  priceDesc,
}

/// All non-text criteria that narrow a product search. Empty collections and
/// `null` numerics mean "no constraint" — the search SQL only adds a `WHERE`
/// for the dimensions the user actually touched, so a freshly opened sheet
/// behaves identically to no filter at all.
class ProductSearchFilter {
  const ProductSearchFilter({
    this.categoryIds = const {},
    this.colors = const {},
    this.minPrice,
    this.maxPrice,
    this.inStockOnly = false,
    this.discountedOnly = false,
    this.deliveryOnly = false,
    this.sort = ProductSearchSort.newest,
  });

  final Set<String> categoryIds;
  final Set<String> colors;
  final int? minPrice;
  final int? maxPrice;
  final bool inStockOnly;
  final bool discountedOnly;
  final bool deliveryOnly;
  final ProductSearchSort sort;

  /// Number of distinct filter facets currently active. Used to render the
  /// badge on the search bar's filter button and the "apply" CTA count.
  /// Sort is excluded — a sort is always implicitly present, so counting it
  /// would make the badge non-zero for an otherwise untouched filter.
  int get activeCount {
    var n = 0;
    if (categoryIds.isNotEmpty) n++;
    if (colors.isNotEmpty) n++;
    if (minPrice != null || maxPrice != null) n++;
    if (inStockOnly) n++;
    if (discountedOnly) n++;
    if (deliveryOnly) n++;
    return n;
  }

  bool get isEmpty => activeCount == 0;
  bool get isNotEmpty => !isEmpty;

  /// True when the filter is in its default state: no facets active AND the
  /// sort is the implicit "newest" default. A non-default sort alone counts
  /// as user intent — we'll search the whole catalogue ordered by it so the
  /// "price low → high" choice in an otherwise-empty sheet returns results
  /// instead of silently doing nothing.
  bool get isDefault => activeCount == 0 && sort == ProductSearchSort.newest;

  ProductSearchFilter copyWith({
    Set<String>? categoryIds,
    Set<String>? colors,
    int? minPrice,
    int? maxPrice,
    bool? inStockOnly,
    bool? discountedOnly,
    bool? deliveryOnly,
    ProductSearchSort? sort,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return ProductSearchFilter(
      categoryIds: categoryIds ?? this.categoryIds,
      colors: colors ?? this.colors,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      inStockOnly: inStockOnly ?? this.inStockOnly,
      discountedOnly: discountedOnly ?? this.discountedOnly,
      deliveryOnly: deliveryOnly ?? this.deliveryOnly,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductSearchFilter &&
          _setEq(categoryIds, other.categoryIds) &&
          _setEq(colors, other.colors) &&
          minPrice == other.minPrice &&
          maxPrice == other.maxPrice &&
          inStockOnly == other.inStockOnly &&
          discountedOnly == other.discountedOnly &&
          deliveryOnly == other.deliveryOnly &&
          sort == other.sort;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(categoryIds),
    Object.hashAllUnordered(colors),
    minPrice,
    maxPrice,
    inStockOnly,
    discountedOnly,
    deliveryOnly,
    sort,
  );

  static bool _setEq(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }
}

abstract class ProductDataSource {
  /// One page of a category's products, ordered + narrowed by [filter]. Drives
  /// the category screen's infinite scroll: page N is `offset = N * limit`.
  /// Returns the catalog-wide [ProductFeedPage.total] for the active filter so
  /// the caller knows when to stop (`offset + items.length < total`).
  Future<ProductFeedPage> listByCategory({
    required String categoryId,
    String? subcategoryId,
    ProductSearchFilter filter,
    int limit = kCategoryPageSize,
    int offset = 0,
  });
  Future<List<ProductModel>> listBySubcategory({
    required String subcategoryId,
  });
  Future<ProductModel> getById(String id);

  /// A page of the home "Siz uchun tavsiya" feed, ordered by [sort]. Drives
  /// the feed's infinite scroll: page N is `offset = N * limit`. Returns the
  /// catalog-wide [ProductFeedPage.total] so the caller knows when to stop.
  Future<ProductFeedPage> listFeed({
    int limit = kHomeFeedPageSize,
    int offset = 0,
    HomeFeedSort sort = HomeFeedSort.recommended,
  });

  /// Case-insensitive `ilike` over name + description, narrowed by [filter].
  /// An empty [query] is allowed when [filter] is non-empty, so the user can
  /// browse the catalogue by filter alone (e.g. "show me discounted sofas").
  Future<List<ProductModel>> search(
    String query, {
    ProductSearchFilter filter,
    int limit = 30,
  });

  /// Rule-based "similar products" for the detail-page carousel. Ranking
  /// (shared subcategory, stock, material, price proximity) is done
  /// server-side by the `get_similar_products` Postgres function.
  Future<List<ProductModel>> listSimilar(
    String productId, {
    int limit = 10,
  });

  /// Synchronous read of the cached first feed page (offset 0, default
  /// [HomeFeedSort.recommended] sort). Returns `null` on cache miss or for
  /// non-caching implementations. The home bloc uses this to paint the feed
  /// at 0 ms on cold start before the backend RTT lands.
  ProductFeedPage? peekFeed() => null;

  /// Synchronous read of a previously-fetched single product. Returns null
  /// on cache miss. The product-detail bloc uses this to render the page
  /// instantly on a re-visit (favourites → detail, cart → detail, deep-link
  /// to a product the user has seen before).
  ProductModel? peekById(String id) => null;

  /// Synchronous read of a previously-fetched default-filtered category
  /// listing's FIRST page. Only returns a hit when no facets / sort /
  /// subcategory are applied — filtered listings are not cached because the
  /// parameter space is too large to be worth the Hive churn.
  ProductFeedPage? peekByCategory(String categoryId) => null;

  /// Synchronous read of a previously-fetched "similar products" carousel.
  /// Returns null on cache miss.
  List<ProductModel>? peekSimilar(String productId, {int limit = 10}) =>
      null;
}

class MockProductDataSource extends ProductDataSource {
  static const _delay = Duration(milliseconds: 400);

  static final List<ProductModel> _all = [
    ProductModel(
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
    ProductModel(
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
    ProductModel(
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
    ProductModel(
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
  Future<ProductFeedPage> listByCategory({
    required String categoryId,
    String? subcategoryId,
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = kCategoryPageSize,
    int offset = 0,
  }) async {
    await Future<void>.delayed(_delay);
    var results = _all.where((p) {
      if (p.categoryId != categoryId) return false;
      if (subcategoryId != null && p.subcategoryId != subcategoryId) {
        return false;
      }
      if (filter.colors.isNotEmpty && !p.colors.any(filter.colors.contains)) {
        return false;
      }
      if (filter.minPrice != null && p.effectivePrice < filter.minPrice!) {
        return false;
      }
      if (filter.maxPrice != null && p.effectivePrice > filter.maxPrice!) {
        return false;
      }
      if (filter.inStockOnly && !p.inStock) return false;
      if (filter.discountedOnly && !p.hasDiscount) return false;
      if (filter.deliveryOnly && !p.hasDelivery) return false;
      return true;
    }).toList();

    switch (filter.sort) {
      case ProductSearchSort.newest:
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case ProductSearchSort.priceAsc:
        results.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
      case ProductSearchSort.priceDesc:
        results.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
    }
    final page = results.skip(offset).take(limit).toList(growable: false);
    return ProductFeedPage(items: page, total: results.length);
  }

  @override
  Future<List<ProductModel>> listBySubcategory({
    required String subcategoryId,
  }) async {
    await Future<void>.delayed(_delay);
    return _all
        .where((p) => p.subcategoryId == subcategoryId)
        .toList(growable: false);
  }

  @override
  Future<ProductModel> getById(String id) async {
    await Future<void>.delayed(_delay);
    return _all.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('Product not found: $id'),
    );
  }

  @override
  Future<ProductFeedPage> listFeed({
    int limit = kHomeFeedPageSize,
    int offset = 0,
    HomeFeedSort sort = HomeFeedSort.recommended,
  }) async {
    await Future<void>.delayed(_delay);
    final sorted = [..._all];
    switch (sort) {
      case HomeFeedSort.recommended:
      case HomeFeedSort.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case HomeFeedSort.popular:
        // No order history in the mock — proxy popularity by stock depth.
        sorted.sort((a, b) => b.stock.compareTo(a.stock));
      case HomeFeedSort.discount:
        sorted.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    }
    final page = sorted.skip(offset).take(limit).toList(growable: false);
    return ProductFeedPage(items: page, total: sorted.length);
  }

  @override
  Future<List<ProductModel>> search(
    String query, {
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = 30,
  }) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty && filter.isEmpty) return const [];
    await Future<void>.delayed(_delay);
    var results = _all.where((p) {
      if (term.isNotEmpty) {
        final hit =
            p.name.toLowerCase().contains(term) ||
            (p.description ?? '').toLowerCase().contains(term);
        if (!hit) return false;
      }
      if (filter.categoryIds.isNotEmpty &&
          !filter.categoryIds.contains(p.categoryId)) {
        return false;
      }
      if (filter.colors.isNotEmpty && !p.colors.any(filter.colors.contains)) {
        return false;
      }
      if (filter.minPrice != null && p.effectivePrice < filter.minPrice!) {
        return false;
      }
      if (filter.maxPrice != null && p.effectivePrice > filter.maxPrice!) {
        return false;
      }
      if (filter.inStockOnly && !p.inStock) return false;
      if (filter.discountedOnly && !p.hasDiscount) return false;
      if (filter.deliveryOnly && !p.hasDelivery) return false;
      return true;
    }).toList();

    switch (filter.sort) {
      case ProductSearchSort.newest:
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case ProductSearchSort.priceAsc:
        results.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
      case ProductSearchSort.priceDesc:
        results.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
    }

    return results.take(limit).toList(growable: false);
  }

  @override
  Future<List<ProductModel>> listSimilar(
    String productId, {
    int limit = 10,
  }) async {
    await Future<void>.delayed(_delay);
    ProductModel? ref;
    for (final p in _all) {
      if (p.id == productId) {
        ref = p;
        break;
      }
    }
    if (ref == null) return const [];
    final refPrice = ref.price;
    final candidates =
        _all
            .where((p) => p.id != productId && p.categoryId == ref!.categoryId)
            .toList()
          ..sort(
            (a, b) => (a.price - refPrice).abs().compareTo(
              (b.price - refPrice).abs(),
            ),
          );
    return candidates.take(limit).toList(growable: false);
  }
}
