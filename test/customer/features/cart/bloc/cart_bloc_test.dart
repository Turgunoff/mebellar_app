import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/cart/bloc/cart_bloc.dart';
import 'package:woody_app/shared/models/cart.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';
import 'package:woody_app/shared/repositories/cart_repository.dart';
import '../../../../fixtures/mocks/mock/mock_cart_repository.dart';
import '../../../../fixtures/mocks/mock/mock_data.dart';
import 'package:woody_app/shared/models/product_model.dart';

/// Snapshot-API repo whose fetch always fails — exercises the refresh
/// completer's failure path without a network.
class _FailingFetchCartRepo extends CartRepository {
  @override
  Stream<Cart> watch() => const Stream<Cart>.empty();
  @override
  Cart get current => const Cart();
  @override
  Future<Cart> fetch() async => const Cart();
  @override
  Future<Cart> addItem(String productId, {int quantity = 1}) async =>
      const Cart();
  @override
  Future<Cart> updateQuantity(String itemId, int quantity) async =>
      const Cart();
  @override
  Future<Cart> removeItem(String itemId) async => const Cart();
  @override
  Future<Cart> clear() async => const Cart();
  @override
  Future<List<CartItemModel>> fetchItems() async =>
      throw Exception('network down');
}

/// Minimal smoke tests for the Sprint 12 cart bloc. Multi-shop grouping is
/// handled at checkout, not here — the cart bloc operates on snapshot
/// rows only, so we focus on the LoadCart/AddToCart/RemoveFromCart loop.
void main() {
  group('CartBloc (mock repository)', () {
    final firstProduct = MockData.products.first;
    final firstSnapshot = ProductModel(
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
        expect(bloc.state.totalPrice, firstSnapshot.price * 2);
      },
    );

    test(
      'pull-to-refresh completer completes on a successful reload',
      () async {
        final bloc = CartBloc(MockCartRepository());
        bloc.add(const LoadCart());
        await Future<void>.delayed(const Duration(milliseconds: 400));

        // An unchanged snapshot is deduped by Equatable — the completer must
        // still settle or the RefreshIndicator spins forever.
        final done = Completer<void>();
        bloc.add(LoadCart(silent: true, completer: done));
        await done.future.timeout(const Duration(seconds: 2));

        await bloc.close();
      },
    );

    test(
      'pull-to-refresh completer completes even when the fetch fails',
      () async {
        final bloc = CartBloc(_FailingFetchCartRepo());
        final done = Completer<void>();
        bloc.add(LoadCart(silent: true, completer: done));
        await done.future.timeout(const Duration(seconds: 2));

        await bloc.close();
      },
    );
  });
}
