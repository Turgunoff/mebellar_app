import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/products/bloc/product_form_bloc.dart';
import 'package:woody_app/shared/mock/mock_seller_product_repository.dart';
import 'package:woody_app/shared/mock/mock_seller_products.dart';
import 'package:woody_app/shared/models/seller_product.dart';

void main() {
  group('ProductFormBloc (mock repository)', () {
    blocTest<ProductFormBloc, ProductFormState>(
      'edit start -> form pre-fills from existing product',
      build: () => ProductFormBloc(MockSellerProductRepository()),
      act: (bloc) {
        bloc.add(ProductFormStarted(existing: MockSellerProducts.products.first));
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.isEdit, isTrue);
        expect(s.productId, MockSellerProducts.products.first.id);
        expect(s.nameUz.isNotEmpty, isTrue);
        expect(s.price, MockSellerProducts.products.first.price);
      },
    );

    blocTest<ProductFormBloc, ProductFormState>(
      'canAdvance enforces required fields per step',
      build: () => ProductFormBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const ProductFormStarted());
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        expect(bloc.state.canAdvanceFrom(ProductFormStep.basics), isFalse);
        expect(bloc.state.canAdvanceFrom(ProductFormStep.category), isFalse);
        expect(bloc.state.canAdvanceFrom(ProductFormStep.pricing), isFalse);
      },
    );

    blocTest<ProductFormBloc, ProductFormState>(
      'basics + category + pricing inputs unblock advance',
      build: () => ProductFormBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const ProductFormStarted());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const ProductFormBasicsChanged(nameUz: 'Test'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const ProductFormCategoryChanged('sofas'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const ProductFormPricingChanged(
            price: 1000000, stock: 5, sku: 'TEST-001'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      },
      verify: (bloc) {
        expect(bloc.state.canAdvanceFrom(ProductFormStep.basics), isTrue);
        expect(bloc.state.canAdvanceFrom(ProductFormStep.category), isTrue);
        expect(bloc.state.canAdvanceFrom(ProductFormStep.pricing), isTrue);
      },
    );

    blocTest<ProductFormBloc, ProductFormState>(
      'submit hits tariff limit on Free plan with 12 seeded products',
      build: () => ProductFormBloc(MockSellerProductRepository()),
      act: (bloc) async {
        bloc.add(const ProductFormStarted());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const ProductFormBasicsChanged(nameUz: 'Yangi mahsulot'));
        bloc.add(const ProductFormCategoryChanged('armchairs'));
        bloc.add(const ProductFormPricingChanged(
            price: 2_000_000, stock: 3, sku: 'NEW-001'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        bloc.add(const ProductFormSubmittedForReview());
        await Future<void>.delayed(const Duration(milliseconds: 800));
      },
      verify: (bloc) {
        // Mock seeds 12 products (mostly approved/pending) but Free plan
        // caps at 5 active — repository should throw TariffLimitException
        // and the BLoC must surface it as a tariffLimit status instead of
        // the silent failure we'd get if the limit were ignored.
        expect(bloc.state.status, ProductFormStatus.tariffLimit);
        expect(bloc.state.tariffSnapshot, isNotNull);
      },
    );

    blocTest<ProductFormBloc, ProductFormState>(
      'enforces 10-image limit',
      build: () {
        final repo = MockSellerProductRepository();
        return ProductFormBloc(repo);
      },
      act: (bloc) async {
        // Pretend we already have 10 images so the limit check trips.
        bloc.add(ProductFormStarted(
          existing: SellerProduct(
            id: 'sp-test',
            name: MockSellerProducts.products.first.name,
            description: MockSellerProducts.products.first.description,
            categorySlug: 'sofas',
            price: 1000000,
            stock: 1,
            sku: 'X-1',
            images: List.generate(
              10,
              (i) => SellerProductImage(
                id: 'img-$i',
                remoteUrl: 'http://example.com/$i.jpg',
              ),
            ),
            primaryImageId: 'img-0',
            status: SellerProductStatus.draft,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ));
      },
      verify: (bloc) {
        expect(bloc.state.images.length, 10);
      },
    );
  });
}
