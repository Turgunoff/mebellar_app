import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/product_detail/bloc/product_detail_bloc.dart';
import 'package:woody_app/shared/models/multilingual_text.dart';
import 'package:woody_app/shared/models/product.dart';
import 'package:woody_app/shared/repositories/product_repository.dart';

class _MockProductRepo extends Mock implements ProductRepository {}

Product _product(String slug, {bool isFavorite = false}) => Product(
      id: slug,
      slug: slug,
      name: const MultilingualText(uz: 'Stol'),
      price: 100000,
      isFavorite: isFavorite,
    );

void main() {
  late _MockProductRepo repo;

  setUp(() => repo = _MockProductRepo());

  blocTest<ProductDetailBloc, ProductDetailState>(
    'ProductDetailRequested emits [loading, ready] on a found product',
    build: () {
      when(() => repo.getBySlug('stol'))
          .thenAnswer((_) async => _product('stol'));
      return ProductDetailBloc(repo);
    },
    act: (bloc) => bloc.add(const ProductDetailRequested('stol')),
    expect: () => [
      isA<ProductDetailState>()
          .having((s) => s.status, 'status', ProductDetailStatus.loading),
      isA<ProductDetailState>()
          .having((s) => s.status, 'status', ProductDetailStatus.ready)
          .having((s) => s.product?.slug, 'slug', 'stol'),
    ],
  );

  blocTest<ProductDetailBloc, ProductDetailState>(
    'ProductDetailRequested emits [loading, failure] when the repo throws',
    build: () {
      when(() => repo.getBySlug(any())).thenThrow(Exception('404'));
      return ProductDetailBloc(repo);
    },
    act: (bloc) => bloc.add(const ProductDetailRequested('missing')),
    expect: () => [
      isA<ProductDetailState>()
          .having((s) => s.status, 'status', ProductDetailStatus.loading),
      isA<ProductDetailState>()
          .having((s) => s.status, 'status', ProductDetailStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<ProductDetailBloc, ProductDetailState>(
    'FavoriteSyncRequested flips the loaded product favorite flag',
    build: () => ProductDetailBloc(repo),
    seed: () => ProductDetailState(
      status: ProductDetailStatus.ready,
      product: _product('stol'),
    ),
    act: (bloc) => bloc.add(
      const ProductDetailFavoriteSyncRequested(isFavorite: true),
    ),
    expect: () => [
      isA<ProductDetailState>()
          .having((s) => s.product?.isFavorite, 'isFavorite', true),
    ],
  );

  blocTest<ProductDetailBloc, ProductDetailState>(
    'FavoriteSyncRequested is a no-op when the flag already matches',
    build: () => ProductDetailBloc(repo),
    seed: () => ProductDetailState(
      status: ProductDetailStatus.ready,
      product: _product('stol', isFavorite: true),
    ),
    act: (bloc) => bloc.add(
      const ProductDetailFavoriteSyncRequested(isFavorite: true),
    ),
    expect: () => const <ProductDetailState>[],
  );
}
