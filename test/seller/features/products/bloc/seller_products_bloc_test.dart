import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/products/bloc/seller_products_bloc.dart';
import 'package:woody_app/shared/mock/mock_seller_product_repository.dart';
import 'package:woody_app/shared/models/seller_product.dart';
import 'package:woody_app/shared/repositories/seller_product_repository.dart';

void main() {
  group('SellerProductsBloc (mock repository)', () {
    blocTest<SellerProductsBloc, SellerProductsState>(
      'fetch -> 12 seeded products',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) => bloc.add(const SellerProductsRequested()),
      wait: const Duration(milliseconds: 500),
      verify: (bloc) {
        expect(bloc.state.status, SellerProductsStatus.ready);
        expect(bloc.state.products.length, 12);
      },
    );

    blocTest<SellerProductsBloc, SellerProductsState>(
      'filter by status returns only matching products',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const SellerProductsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        bloc.add(const SellerProductsFilterChanged(SellerProductFilter(
          statuses: {SellerProductStatus.draft},
        )));
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(
          bloc.state.visibleProducts
              .every((p) => p.status == SellerProductStatus.draft),
          isTrue,
        );
        expect(bloc.state.visibleProducts.length, greaterThan(0));
      },
    );

    blocTest<SellerProductsBloc, SellerProductsState>(
      'submit for review transitions draft -> pending',
      build: () => SellerProductsBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const SellerProductsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final draft = bloc.state.products
            .firstWhere((p) => p.status == SellerProductStatus.draft);
        bloc.add(SellerProductSubmitted(draft.id));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      verify: (bloc) {
        // The earlier draft should now be pending review (no longer draft).
        final pendingCount = bloc.state.products
            .where((p) => p.status == SellerProductStatus.pendingReview)
            .length;
        expect(pendingCount, greaterThan(2),
            reason:
                'Seed has 2 pending products; submit should add at least 1 more');
      },
    );
  });
}
