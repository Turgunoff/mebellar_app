import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/product_list/cubit/product_list_cubit.dart';
import 'package:woody_app/shared/models/category_model.dart';
import 'package:woody_app/shared/models/supabase_product_model.dart';
import 'package:woody_app/shared/repositories/supabase_category_repository.dart';
import 'package:woody_app/shared/repositories/supabase_product_data_source.dart';

class _MockProductSource extends Mock implements SupabaseProductDataSource {}

class _MockCategorySource extends Mock implements CategoryDataSource {}

SupabaseProductModel _sp(String id) => SupabaseProductModel(
      id: id,
      categoryId: 'cat-1',
      name: 'Product $id',
      price: 100000,
      images: const [],
      stock: 5,
      createdAt: DateTime.utc(2026, 5, 16),
    );

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

  blocTest<ProductListCubit, ProductListState>(
    'load emits [loading, loaded] with the category products',
    build: () {
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => [_sp('a'), _sp('b')]);
      return build();
    },
    act: (cubit) => cubit.load(categoryId: 'cat-1'),
    expect: () => [
      isA<ProductListState>()
          .having((s) => s.status, 'status', ProductListStatus.loading),
      isA<ProductListState>()
          .having((s) => s.status, 'status', ProductListStatus.loaded)
          .having((s) => s.products.length, 'count', 2),
    ],
  );

  blocTest<ProductListCubit, ProductListState>(
    'load emits [loading, failure] when the source throws',
    build: () {
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
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
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => [_sp('a')]);
      return build();
    },
    act: (cubit) => cubit.load(categoryId: 'cat-1', subcategoryId: 'sub-9'),
    verify: (_) {
      verify(
        () => source.listByCategory(
          categoryId: 'cat-1',
          subcategoryId: 'sub-9',
          filter: any(named: 'filter'),
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
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => [_sp('a')]);
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
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => [_sp('x')]);
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
        ),
      ).called(1);
    },
  );

  blocTest<ProductListCubit, ProductListState>(
    'selectSubcategory(null) clears the filter back to All',
    build: () {
      when(() => categorySource.list()).thenAnswer((_) async => const []);
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => [_sp('y')]);
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
        ),
      ).called(1);
    },
  );

  blocTest<ProductListCubit, ProductListState>(
    'applyFilter re-queries with the new facets and updates state.filter',
    build: () {
      when(() => categorySource.list()).thenAnswer((_) async => const []);
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => [_sp('z')]);
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
        ),
      ).called(1);
    },
  );
}
