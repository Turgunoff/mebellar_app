import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/cart/bloc/cart_bloc.dart';
import 'package:woody_app/customer/features/cart/screens/cart_screen.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';

/// ROADMAP B.5 — widget tests for the cart screen. `CartBloc` is replaced by
/// a `MockBloc` so each render state (loading / empty / loaded) is pinned
/// without a repository or network.
class _MockCartBloc extends MockBloc<CartEvent, CartState>
    implements CartBloc {}

void main() {
  late _MockCartBloc bloc;

  setUp(() => bloc = _MockCartBloc());

  Widget harness() => MaterialApp(
        home: Scaffold(
          body: BlocProvider<CartBloc>.value(
            value: bloc,
            child: const CartScreen(),
          ),
        ),
      );

  testWidgets('shows a spinner while the cart is loading', (tester) async {
    whenListen(
      bloc,
      const Stream<CartState>.empty(),
      initialState: const CartState(status: CartStatus.loading),
    );
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the empty state when the cart has no items',
      (tester) async {
    whenListen(
      bloc,
      const Stream<CartState>.empty(),
      initialState: const CartState(status: CartStatus.ready),
    );
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(find.text("Savatchangiz bo'sh"), findsOneWidget);
  });

  testWidgets('renders a row for each loaded cart item', (tester) async {
    const item = CartItemModel(
      id: 'c1',
      productId: 'p1',
      productName: 'Premium Divan',
      productImage: '',
      productPrice: 4500000,
      quantity: 2,
    );
    whenListen(
      bloc,
      const Stream<CartState>.empty(),
      initialState: const CartState(
        status: CartStatus.ready,
        items: [item],
      ),
    );
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(find.text('Premium Divan'), findsOneWidget);
  });
}
