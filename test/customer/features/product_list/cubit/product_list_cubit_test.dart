import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/product_list/cubit/product_list_cubit.dart';
import 'package:woody_app/shared/models/category_model.dart';
import 'package:woody_app/shared/models/product_model.dart';
import 'package:woody_app/shared/repositories/category_data_source.dart';
import 'package:woody_app/shared/repositories/product_data_source.dart';

class _MockProductSource extends Mock implements ProductDataSource {}

class _MockCategorySource extends Mock implements CategoryDataSource {}

ProductModel _sp(String id) => ProductModel(
      id: id,
      categoryId: 'cat-1',
      name: 'Product $id',
      price: 100000,
      images: const [],
      stock: 5,
      createdAt: DateTime.utc(2026, 5, 16),
    );

List<ProductModel> _items(int from, int count) =>
    List.generate(count, (i) => _sp('p${from + i}'));

ProductFeedPage _page(List<ProductModel> items, {required int total}) =>
    ProductFeedPage(items: items, total: total);

CategoryModel _cat(String id, {List<SubcategoryModel> subs = const []}) =>
    CategoryModel(
      id: id,
      name: 'Category $id',
      sortOrder: 1,
      subcategories: subs,
    );

void main() {
  late _MockProductSource source;
  late _MockCategorySource categorySource;

  setUpAll(() {
    registerFallbackValue(const ProductSearchFilter());
  });

  setUp(() {
    source = _MockProductSource();
    categorySource = _MockCategorySource();
    // Default categories stub — tests can override per-case if they care
    // about subcategory discovery.
    when(() => categorySource.list()).thenAnswer((_) async => const []);
  });

  ProductListCubit build() => ProductListCubit(source, categorySource);

  /// Stub `listByCategory` with a single fixed page. The `limit`/`offset`
  /// matchers are mandatory now the cubit always passes them.
  void stubPage(ProductFeedPage page) {
    when(
      () => source.listByCategory(
        categoryId: any(named: 'categoryId'),
        subcategoryId: any(named: 'subcategoryId'),
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => page);
  }

  /// Stub `listByCategory` to serve a [total]-row catalogue in pages, slicing
  /// by the `offset`/`limit` the cubit requests — so a `load` + `loadMore`
  /// sequence walks the catalogue exactly as the real backend would.
  void stubPaginated(int total) {
    final all = _items(0, total);
    when(
      () => source.listByCategory(
        categoryId: any(named: 'categoryId'),
        subcategoryId: any(named: 'subcategoryId'),
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((inv) async {
      final offset = inv.namedArguments[#offset] as int;
      final limit = inv.namedArguments[#limit] as int;
      return _page(
        all.skip(offset).take(limit).toList(),
        total: all.length,
      );
    });
  }

  blocTest<ProductListCubit, ProductListState>(
    'load emits [loading, loaded] with the category products',
    build: () {
      stubPage(_page([_sp('a'), _sp('b')], total: 2));
      return build();
    },
    act: (cubit) => cubit.load(categoryId: 'cat-1'),
    expect: () => [
      isA<ProductListState>()
          .having((s) => s.status, 'status', ProductListStatus.loading),
      isA<ProductListState>()
          .having((s) => s.status, 'status', ProductListStatus.loaded)
          .having((s) => s.products.length, 'count', 2)
          // A short first page is the last page.
          .having((s) => s.hasMore, 'hasMore', false),
    ],
  );

  blocTest<ProductListCubit, ProductListState>(
    'load sets hasMore when a full page leaves more in the catalogue',
    build: () {
      stubPaginated(30);
      return build();
    },
    act: (cubit) => cubit.load(categoryId: 'cat-1'),
    expect: () => [
      isA<ProductListState>()
          .having((s) => s.status, 'status', ProductListStatus.loading),
      isA<ProductListState>()
          .having((s) => s.status, 'status', ProductListStatus.loaded)
          .having((s) => s.products.length, 'count', kCategoryPageSize)
          .having((s) => s.hasMore, 'hasMore', true),
    ],
  );

  blocTest<ProductListCubit, ProductListState>(
    'loadMore appends the next page and clears hasMore at the end',
    build: () {
      stubPaginated(30);
      return build();
    },
    act: (cubit) async {
      await cubit.load(categoryId: 'cat-1');
      await cubit.loadMore();
    },
    expect: () => [
      isA<ProductListState>()
          .having((s) => s.status, 'status', ProductListStatus.loading),
      isA<ProductListState>()
          .having((s) => s.products.length, 'page1', kCategoryPageSize)
          .having((s) => s.hasMore, 'hasMore', true),
      isA<ProductListState>()
          .having((s) => s.loadingMore, 'loadingMore', true),
      isA<ProductListState>()
          .having((s) => s.products.length, 'page1+2', 30)
          .having((s) => s.hasMore, 'hasMore', false)
          .having((s) => s.loadingMore, 'loadingMore', false),
    ],
  );

  blocTest<ProductListCubit, ProductListState>(
    'loadMore is a no-op when the first page already exhausted the catalogue',
    build: () {
      stubPage(_page([_sp('a'), _sp('b')], total: 2));
      return build();
    },
    act: (cubit) async {
      await cubit.load(categoryId: 'cat-1');
      await cubit.loadMore();
    },
    verify: (_) {
      // Only the initial page fetch — loadMore bailed on hasMore == false.
      verify(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);
    },
  );

  blocTest<ProductListCubit, ProductListState>(
    'loadMore dedups ids that overlap the already-loaded page',
    build: () {
      final all = _items(0, 30);
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((inv) async {
        final offset = inv.namedArguments[#offset] as int;
        final limit = inv.namedArguments[#limit] as int;
        // Shift the second page back by one row so p14 is returned twice — a
        // catalogue insert between pages would do this.
        final start = offset == 0 ? 0 : offset - 1;
        return _page(all.skip(start).take(limit).toList(), total: all.length);
      });
      return build();
    },
    act: (cubit) async {
      await cubit.load(categoryId: 'cat-1');
      await cubit.loadMore();
    },
    verify: (cubit) {
      final ids = cubit.state.products.map((p) => p.id).toList();
      // No duplicate ids despite the overlapping page.
      expect(ids.toSet().length, ids.length);
    },
  );

  blocTest<ProductListCubit, ProductListState>(
    'load emits [loading, failure] when the source throws',
    build: () {
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenThrow(Exception('query failed'));
      return build();
    },
    act: (cubit) => cubit.load(categoryId: 'cat-1'),
    expect: () => [
      isA<ProductListState>()
          .having((s) => s.status, 'status', ProductListStatus.loading),
      isA<ProductListState>()
          .having((s) => s.status, 'status', ProductListStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<ProductListCubit, ProductListState>(
    'load forwards the subcategory filter to the data source',
    build: () {
      stubPage(_page([_sp('a')], total: 1));
      return build();
    },
    act: (cubit) => cubit.load(categoryId: 'cat-1', subcategoryId: 'sub-9'),
    verify: (_) {
      verify(
        () => source.listByCategory(
          categoryId: 'cat-1',
          subcategoryId: 'sub-9',
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);
    },
  );

  blocTest<ProductListCubit, ProductListState>(
    'load surfaces the matching category\'s subcategories',
    build: () {
      when(() => categorySource.list()).thenAnswer(
        (_) async => [
          _cat('cat-1', subs: const [
            SubcategoryModel(id: 's1', categoryId: 'cat-1', name: 'Corner'),
            SubcategoryModel(id: 's2', categoryId: 'cat-1', name: 'Loveseat'),
          ]),
          _cat('cat-2'),
        ],
      );
      stubPage(_page([_sp('a')], total: 1));
      return build();
    },
    act: (cubit) => cubit.load(categoryId: 'cat-1'),
    expect: () => [
      isA<ProductListState>()
          .having((s) => s.status, 'status', ProductListStatus.loading),
      isA<ProductListState>()
          .having((s) => s.status, 'status', ProductListStatus.loaded)
          .having((s) => s.subcategories.length, 'subcategories', 2)
          .having((s) => s.selectedSubcategoryId, 'selectedId', isNull),
    ],
  );

  blocTest<ProductListCubit, ProductListState>(
    'selectSubcategory re-queries with the new filter and updates selectedId',
    build: () {
      when(() => categorySource.list()).thenAnswer((_) async => const []);
      stubPage(_page([_sp('x')], total: 1));
      return build();
    },
    act: (cubit) async {
      await cubit.load(categoryId: 'cat-1');
      await cubit.selectSubcategory('sub-3');
    },
    verify: (_) {
      verify(
        () => source.listByCategory(
          categoryId: 'cat-1',
          subcategoryId: 'sub-3',
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);
    },
  );

  blocTest<ProductListCubit, ProductListState>(
    'selectSubcategory(null) clears the filter back to All',
    build: () {
      when(() => categorySource.list()).thenAnswer((_) async => const []);
      stubPage(_page([_sp('y')], total: 1));
      return build();
    },
    act: (cubit) async {
      await cubit.load(categoryId: 'cat-1', subcategoryId: 'sub-3');
      await cubit.selectSubcategory(null);
    },
    verify: (cubit) {
      expect(cubit.state.selectedSubcategoryId, isNull);
      verify(
        () => source.listByCategory(
          categoryId: 'cat-1',
          subcategoryId: null,
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);
    },
  );

  blocTest<ProductListCubit, ProductListState>(
    'applyFilter re-queries with the new facets and updates state.filter',
    build: () {
      when(() => categorySource.list()).thenAnswer((_) async => const []);
      stubPage(_page([_sp('z')], total: 1));
      return build();
    },
    act: (cubit) async {
      await cubit.load(categoryId: 'cat-1');
      await cubit.applyFilter(
        const ProductSearchFilter(discountedOnly: true),
      );
    },
    verify: (cubit) {
      expect(cubit.state.filter.discountedOnly, isTrue);
      verify(
        () => source.listByCategory(
          categoryId: 'cat-1',
          subcategoryId: null,
          filter: const ProductSearchFilter(discountedOnly: true),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);
    },
  );

  // --- cache-paint race guards (load() must not clobber newer state) --------

  test(
    'load background refresh does not clobber pages appended by loadMore '
    'during the cache-paint window',
    () async {
      final all = _items(0, 30);
      // Warm cache → load() paints the first page synchronously and the screen
      // is immediately interactive (hasMore true).
      when(() => source.peekByCategory(any()))
          .thenReturn(_page(all.take(kCategoryPageSize).toList(), total: 30));
      when(() => categorySource.peek()).thenReturn([_cat('cat-1')]);

      // The background first-page refresh (offset 0) hangs until we release it;
      // the loadMore fetch (offset 15) resolves immediately.
      final refresh = Completer<ProductFeedPage>();
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((inv) {
        final offset = inv.namedArguments[#offset] as int;
        if (offset == 0) return refresh.future;
        return Future.value(
          _page(all.skip(offset).take(kCategoryPageSize).toList(), total: 30),
        );
      });

      final cubit = build();
      final loadFuture = cubit.load(categoryId: 'cat-1');
      // Cache paint landed.
      expect(cubit.state.products.length, kCategoryPageSize);
      expect(cubit.state.hasMore, isTrue);

      // User scrolls → page 2 appends while the refresh is still in flight.
      await cubit.loadMore();
      expect(cubit.state.products.length, 30);
      expect(cubit.state.hasMore, isFalse);

      // The stale first-page refresh now lands — it must NOT drop page 2 or
      // rewind the cursor.
      refresh.complete(_page(all.take(kCategoryPageSize).toList(), total: 30));
      await loadFuture;

      expect(cubit.state.products.length, 30);
      expect(cubit.state.hasMore, isFalse);
      await cubit.close();
    },
  );

  test(
    'load background refresh does not overwrite a subcategory swap made '
    'during the cache-paint window',
    () async {
      const subs = [
        SubcategoryModel(id: 's1', categoryId: 'cat-1', name: 'Corner'),
      ];
      when(() => source.peekByCategory(any()))
          .thenReturn(_page(_items(0, kCategoryPageSize), total: 30));
      when(() => categorySource.peek())
          .thenReturn([_cat('cat-1', subs: subs)]);
      when(() => categorySource.list())
          .thenAnswer((_) async => [_cat('cat-1', subs: subs)]);

      // The default ("All") background refresh hangs; the subcategory fetch
      // resolves immediately with its own distinct product.
      final refresh = Completer<ProductFeedPage>();
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((inv) {
        final sub = inv.namedArguments[#subcategoryId] as String?;
        if (sub == null) return refresh.future;
        return Future.value(_page([_sp('sub-prod')], total: 1));
      });

      final cubit = build();
      final loadFuture = cubit.load(categoryId: 'cat-1');
      expect(cubit.state.selectedSubcategoryId, isNull);

      // User taps a chip during the cache-paint window.
      await cubit.selectSubcategory('s1');
      expect(cubit.state.selectedSubcategoryId, 's1');
      expect(cubit.state.products.single.id, 'sub-prod');

      // The stale "All" refresh lands late — it must not overwrite the
      // subcategory's products nor reset the cursor.
      refresh.complete(_page(_items(0, kCategoryPageSize), total: 30));
      await loadFuture;

      expect(cubit.state.selectedSubcategoryId, 's1');
      expect(cubit.state.products.single.id, 'sub-prod');
      await cubit.close();
    },
  );
}
