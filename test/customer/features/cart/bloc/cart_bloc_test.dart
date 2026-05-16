import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/cart/bloc/cart_bloc.dart';
import 'package:woody_app/shared/mock/mock_cart_repository.dart';
import 'package:woody_app/shared/mock/mock_data.dart';
import 'package:woody_app/shared/models/supabase_product_model.dart';

/// Minimal smoke tests for the Sprint 12 cart bloc. Multi-shop grouping has
/// moved to the legacy CheckoutBloc — the new bloc operates on snapshot
/// rows only, so we focus on the LoadCart/AddToCart/RemoveFromCart loop.
void main() {
  group('CartBloc (mock repository)', () {
    final firstProduct = MockData.products.first;
    final firstSnapshot = SupabaseProductModel(
      id: firstProduct.id,
      categoryId: firstProduct.categorySlug ?? '',
      name: firstProduct.name.get('uz'),
      price: firstProduct.price.toDouble(),
      images: firstProduct.images,
      stock: firstProduct.stock,
      createdAt: DateTime.now(),
    );

    blocTest<CartBloc, CartState>(
      'load -> empty cart on initial fetch',
      build: () => CartBloc(MockCartRepository()),
      act: (bloc) => bloc.add(const LoadCart()),
      wait: const Duration(milliseconds: 400),
      skip: 1,
      expect: () => [
        isA<CartState>()
            .having((s) => s.status, 'status', CartStatus.ready)
            .having((s) => s.items, 'items', isEmpty),
      ],
    );

    blocTest<CartBloc, CartState>(
      'add -> increments quantity for existing product',
      build: () => CartBloc(MockCartRepository()),
      act: (bloc) async {
        bloc.add(AddToCart(firstSnapshot));
        await Future<void>.delayed(const Duration(milliseconds: 400));
        bloc.add(AddToCart(firstSnapshot, quantity: 2));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      verify: (bloc) {
        expect(bloc.state.items.length, 1);
        expect(bloc.state.items.first.quantity, 3);
      },
    );

    blocTest<CartBloc, CartState>(
      'remove -> drops the item from cart',
      build: () => CartBloc(MockCartRepository()),
      act: (bloc) async {
        bloc.add(AddToCart(firstSnapshot));
        await Future<void>.delayed(const Duration(milliseconds: 400));
        bloc.add(RemoveFromCart(firstSnapshot.id));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      verify: (bloc) {
        expect(bloc.state.items, isEmpty);
      },
    );

    blocTest<CartBloc, CartState>(
      'totalPrice — sums line totals across rows',
      build: () => CartBloc(MockCartRepository()),
      act: (bloc) async {
        bloc.add(AddToCart(firstSnapshot, quantity: 2));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      verify: (bloc) {
        expect(
          bloc.state.totalPrice,
          firstSnapshot.price * 2,
        );
      },
    );
  });
}
