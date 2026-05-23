import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supabase_product_model.dart';

/// Ordering options accepted by [SupabaseProductDataSource.search]. The search
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
  bool get isDefault =>
      activeCount == 0 && sort == ProductSearchSort.newest;

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

abstract class SupabaseProductDataSource {
  Future<List<SupabaseProductModel>> listByCategory({
    required String categoryId,
    String? subcategoryId,
    ProductSearchFilter filter,
  });
  Future<List<SupabaseProductModel>> listBySubcategory({
    required String subcategoryId,
  });
  Future<SupabaseProductModel> getById(String id);

  /// Newest-first products across the catalog. Used by the Home screen's
  /// "Recommended for you" rail until we have a real recs engine.
  Future<List<SupabaseProductModel>> listAll({int limit = 10});

  /// Case-insensitive `ilike` over name + description, narrowed by [filter].
  /// An empty [query] is allowed when [filter] is non-empty, so the user can
  /// browse the catalogue by filter alone (e.g. "show me discounted sofas").
  Future<List<SupabaseProductModel>> search(
    String query, {
    ProductSearchFilter filter,
    int limit = 30,
  });

  /// Rule-based "similar products" for the detail-page carousel. Ranking
  /// (shared subcategory, stock, material, price proximity) is done
  /// server-side by the `get_similar_products` Postgres function.
  Future<List<SupabaseProductModel>> listSimilar(
    String productId, {
    int limit = 10,
  });
}

class SupabaseProductRepository implements SupabaseProductDataSource {
  SupabaseProductRepository({required SupabaseClient supabase})
    : _supabase = supabase;

  final SupabaseClient _supabase;

  // `product_variants` carries the per-product discount (`discount_price`);
  // embedding it lets the customer surface show the same discount the seller
  // sees. RLS exposes variants for every visible product.
  static const _select =
      '*, shops(name), product_variants(price, discount_price)';

  /// Customer catalogue only ever shows `approved` products. Anything in
  /// `draft` / `pending_review` / `rejected` / `archived` is seller-internal
  /// (see `SellerProductStatus`). Every query below filters on this so a
  /// product stays hidden from buyers until moderation approves it; the
  /// `products` SELECT RLS enforces the same rule server-side.
  static const _approvedStatus = 'approved';

  @override
  Future<List<SupabaseProductModel>> listByCategory({
    required String categoryId,
    String? subcategoryId,
    ProductSearchFilter filter = const ProductSearchFilter(),
  }) async {
    var query = _supabase
        .from('products')
        .select(_select)
        .eq('status', _approvedStatus)
        .eq('category_id', categoryId);

    if (subcategoryId != null) {
      query = query.eq('subcategory_id', subcategoryId);
    }
    // `filter.categoryIds` is ignored here on purpose — the explicit
    // `categoryId` argument already pins the category and would conflict.
    query = _applyFacetFilters(query, filter);

    final data = await _applySort(query, filter.sort);
    return _decodeAndPostFilter(data, filter);
  }

  @override
  Future<List<SupabaseProductModel>> listBySubcategory({
    required String subcategoryId,
  }) async {
    final data = await _supabase
        .from('products')
        .select(_select)
        .eq('status', _approvedStatus)
        .eq('subcategory_id', subcategoryId)
        .order('created_at', ascending: false);
    return data.map(SupabaseProductModel.fromJson).toList(growable: false);
  }

  @override
  Future<SupabaseProductModel> getById(String id) async {
    final data = await _supabase
        .from('products')
        .select(_select)
        .eq('id', id)
        .eq('status', _approvedStatus)
        .single();
    return SupabaseProductModel.fromJson(data);
  }

  @override
  Future<List<SupabaseProductModel>> listAll({int limit = 10}) async {
    final data = await _supabase
        .from('products')
        .select(_select)
        .eq('status', _approvedStatus)
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
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = 30,
  }) async {
    final term = query.trim();
    // Allow filter-only and sort-only browsing: an empty query is fine as
    // long as the user has expressed *some* intent — either a facet filter
    // or a non-default sort (e.g. "show me the cheapest items"). Truly
    // empty input would dump the entire catalogue in default order, which
    // is what the home rails already do — guard against that.
    if (term.isEmpty && filter.isDefault) return const [];

    var query0 = _supabase
        .from('products')
        .select(_select)
        .eq('status', _approvedStatus);

    if (term.isNotEmpty) {
      // Escape the % and _ wildcards so user input can't broaden the match.
      final escaped = term
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      final pattern = '%$escaped%';
      query0 = query0.or('name.ilike.$pattern,description.ilike.$pattern');
    }

    if (filter.categoryIds.isNotEmpty) {
      query0 = query0.inFilter('category_id', filter.categoryIds.toList());
    }
    query0 = _applyFacetFilters(query0, filter);

    // `discountedOnly` lives on the variant row, not the product, so it
    // can't be expressed as a column filter — we drop non-discounted rows
    // in Dart after the round-trip. Doubling the SQL `LIMIT` when that
    // filter is on keeps the post-filter result size reasonable for the
    // common case where roughly half of products have a discount.
    final fetchLimit = filter.discountedOnly ? limit * 2 : limit;

    final data = await _applySort(query0, filter.sort).limit(fetchLimit);
    return _decodeAndPostFilter(data, filter, capAt: limit);
  }

  /// Apply every non-text, non-category filter facet to [query]. Shared by
  /// `search` and `listByCategory` so a new facet (e.g. "free shipping")
  /// only needs to be wired up once for both code paths.
  PostgrestFilterBuilder<PostgrestList> _applyFacetFilters(
    PostgrestFilterBuilder<PostgrestList> query,
    ProductSearchFilter filter,
  ) {
    if (filter.colors.isNotEmpty) {
      // `colors` on products is `text[]`; `overlaps` matches when any of
      // the requested slugs appears on the product — the OR-across-colors
      // a shopper expects when ticking multiple swatches.
      query = query.overlaps('colors', filter.colors.toList());
    }
    if (filter.minPrice != null) {
      query = query.gte('price', filter.minPrice!);
    }
    if (filter.maxPrice != null) {
      query = query.lte('price', filter.maxPrice!);
    }
    if (filter.inStockOnly) {
      query = query.gt('stock', 0);
    }
    if (filter.deliveryOnly) {
      query = query.eq('has_delivery', true);
    }
    return query;
  }

  /// Convert a PostgREST payload into models and apply post-fetch filters
  /// that can't be expressed in SQL (today: `discountedOnly`, which lives
  /// on the variant row). [capAt] hard-caps the returned list — pass it
  /// from `search` to keep the page size bounded after the post-filter,
  /// omit for category browsing where the category arg already bounds it.
  List<SupabaseProductModel> _decodeAndPostFilter(
    List<dynamic> data,
    ProductSearchFilter filter, {
    int? capAt,
  }) {
    var results = data
        .whereType<Map<String, dynamic>>()
        .map(SupabaseProductModel.fromJson)
        .toList();
    if (filter.discountedOnly) {
      results = results.where((p) => p.hasDiscount).toList();
    }
    if (capAt != null && results.length > capAt) {
      results = results.sublist(0, capAt);
    }
    return List.unmodifiable(results);
  }

  /// Apply the user-chosen ordering. Kept separate so the same builder can be
  /// reused if we add more sort modes — every new mode lands here AND in
  /// [ProductSearchSort]. Falls through to created_at when an unknown value
  /// somehow reaches the data layer (defensive — the enum prevents this at
  /// the call site).
  PostgrestTransformBuilder<PostgrestList> _applySort(
    PostgrestFilterBuilder<PostgrestList> query,
    ProductSearchSort sort,
  ) {
    return switch (sort) {
      ProductSearchSort.newest => query.order('created_at', ascending: false),
      ProductSearchSort.priceAsc => query.order('price', ascending: true),
      ProductSearchSort.priceDesc => query.order('price', ascending: false),
    };
  }

  @override
  Future<List<SupabaseProductModel>> listSimilar(
    String productId, {
    int limit = 10,
  }) async {
    // `get_similar_products` returns `setof products`, so `.select(_select)`
    // both reshapes the rows and embeds `shops(name)` — same as the table
    // queries above. Server-side ORDER BY is preserved by PostgREST. The
    // function itself filters to `approved` products, so the carousel never
    // surfaces seller-internal rows and its LIMIT counts approved rows only.
    final data = await _supabase
        .rpc(
          'get_similar_products',
          params: {'p_product_id': productId, 'p_limit': limit},
        )
        .select(_select);
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
    ProductSearchFilter filter = const ProductSearchFilter(),
  }) async {
    await Future<void>.delayed(_delay);
    var results = _all.where((p) {
      if (p.categoryId != categoryId) return false;
      if (subcategoryId != null && p.subcategoryId != subcategoryId) {
        return false;
      }
      if (filter.colors.isNotEmpty &&
          !p.colors.any(filter.colors.contains)) {
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
    return List.unmodifiable(results);
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
    ProductSearchFilter filter = const ProductSearchFilter(),
    int limit = 30,
  }) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty && filter.isEmpty) return const [];
    await Future<void>.delayed(_delay);
    var results = _all.where((p) {
      if (term.isNotEmpty) {
        final hit = p.name.toLowerCase().contains(term) ||
            (p.description ?? '').toLowerCase().contains(term);
        if (!hit) return false;
      }
      if (filter.categoryIds.isNotEmpty &&
          !filter.categoryIds.contains(p.categoryId)) {
        return false;
      }
      if (filter.colors.isNotEmpty &&
          !p.colors.any(filter.colors.contains)) {
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
  Future<List<SupabaseProductModel>> listSimilar(
    String productId, {
    int limit = 10,
  }) async {
    await Future<void>.delayed(_delay);
    SupabaseProductModel? ref;
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
