import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/catalog/bloc/catalog_bloc.dart';
import 'package:woody_app/shared/models/multilingual_text.dart';
import 'package:woody_app/shared/models/paginated.dart';
import 'package:woody_app/shared/models/product.dart';
import 'package:woody_app/shared/repositories/product_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockProductRepo extends Mock implements ProductRepository {}

Product _product(String id) => Product(
      id: id,
      slug: id,
      name: const MultilingualText(uz: 'Stol'),
      price: 100000,
    );

Paginated<Product> _page(List<String> ids, {bool hasNext = false, int page = 1}) =>
    Paginated(
      items: ids.map(_product).toList(),
      page: page,
      perPage: 20,
      total: hasNext ? 100 : ids.length,
      hasNext: hasNext,
    );

void main() {
  late _MockProductRepo repo;

  setUp(() {
    repo = _MockProductRepo();
    registerFallbackValue(const ProductFilter());
  });

  blocTest<CatalogBloc, CatalogState>(
    'emits loading then ready on initial fetch',
    build: () {
      when(() => repo.list(filter: any(named: 'filter'), page: 1, perPage: 20))
          .thenAnswer((_) async => _page(['a', 'b'], hasNext: true));
      return CatalogBloc(repo);
    },
    act: (bloc) => bloc.add(const CatalogRequested()),
    expect: () => [
      isA<CatalogState>().having((s) => s.status, 'loading', CatalogStatus.loading),
      isA<CatalogState>()
          .having((s) => s.status, 'ready', CatalogStatus.ready)
          .having((s) => s.products.length, 'products', 2)
          .having((s) => s.hasNext, 'hasNext', true),
    ],
  );

  blocTest<CatalogBloc, CatalogState>(
    'pagination appends products',
    build: () {
      when(() => repo.list(filter: any(named: 'filter'), page: 1, perPage: 20))
          .thenAnswer((_) async => _page(['a'], hasNext: true));
      when(() => repo.list(filter: any(named: 'filter'), page: 2, perPage: 20))
          .thenAnswer((_) async => _page(['b'], page: 2));
      return CatalogBloc(repo);
    },
    act: (bloc) async {
      bloc.add(const CatalogRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const CatalogNextPageRequested());
    },
    skip: 1,
    expect: () => [
      isA<CatalogState>()
          .having((s) => s.products.map((p) => p.id).toList(), 'page1', ['a']),
      isA<CatalogState>().having((s) => s.status, 'loadingMore',
          CatalogStatus.loadingMore),
      isA<CatalogState>()
          .having((s) => s.products.map((p) => p.id).toList(), 'merged',
              ['a', 'b'])
          .having((s) => s.hasNext, 'hasNext', false),
    ],
  );

  blocTest<CatalogBloc, CatalogState>(
    'filter change re-fetches with new filter',
    build: () {
      when(() => repo.list(filter: any(named: 'filter'), page: 1, perPage: 20))
          .thenAnswer((_) async => _page(['a']));
      return CatalogBloc(repo);
    },
    act: (bloc) =>
        bloc.add(CatalogFilterChanged(const ProductFilter(categorySlug: 'sofas'))),
    skip: 2,
    expect: () => [
      isA<CatalogState>().having(
        (s) => s.filter.categorySlug,
        'category',
        'sofas',
      ),
    ],
    verify: (_) {
      final captured = verify(
        () => repo.list(
          filter: captureAny(named: 'filter'),
          page: 1,
          perPage: 20,
        ),
      ).captured;
      expect((captured.last as ProductFilter).categorySlug, 'sofas');
    },
  );
}
