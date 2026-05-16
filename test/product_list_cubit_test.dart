import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/product_list/cubit/product_list_cubit.dart';
import 'package:woody_app/shared/models/supabase_product_model.dart';
import 'package:woody_app/shared/repositories/supabase_product_data_source.dart';

class _MockProductSource extends Mock implements SupabaseProductDataSource {}

SupabaseProductModel _sp(String id) => SupabaseProductModel(
      id: id,
      categoryId: 'cat-1',
      name: 'Product $id',
      price: 100000,
      images: const [],
      stock: 5,
      createdAt: DateTime.utc(2026, 5, 16),
    );

void main() {
  late _MockProductSource source;

  setUp(() => source = _MockProductSource());

  blocTest<ProductListCubit, ProductListState>(
    'load emits [loading, loaded] with the category products',
    build: () {
      when(
        () => source.listByCategory(
          categoryId: any(named: 'categoryId'),
          subcategoryId: any(named: 'subcategoryId'),
        ),
      ).thenAnswer((_) async => [_sp('a'), _sp('b')]);
      return ProductListCubit(source);
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
        ),
      ).thenThrow(Exception('query failed'));
      return ProductListCubit(source);
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
        ),
      ).thenAnswer((_) async => [_sp('a')]);
      return ProductListCubit(source);
    },
    act: (cubit) =>
        cubit.load(categoryId: 'cat-1', subcategoryId: 'sub-9'),
    verify: (_) {
      verify(
        () => source.listByCategory(
          categoryId: 'cat-1',
          subcategoryId: 'sub-9',
        ),
      ).called(1);
    },
  );
}
