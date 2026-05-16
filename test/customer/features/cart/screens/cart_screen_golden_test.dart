import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/cart/bloc/cart_bloc.dart';
import 'package:woody_app/customer/features/cart/screens/cart_screen.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';

/// ROADMAP B.5 — golden tests for the cart screen.
///
/// Regenerate baselines:
///   flutter test --update-goldens test/customer/features/cart/screens/cart_screen_golden_test.dart
class _MockCartBloc extends MockBloc<CartEvent, CartState>
    implements CartBloc {}

void main() {
  late _MockCartBloc bloc;

  setUp(() => bloc = _MockCartBloc());

  Future<void> pumpCart(WidgetTester tester, CartState state) async {
    whenListen(bloc, const Stream<CartState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<CartBloc>.value(
            value: bloc,
            child: const CartScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('empty cart matches its golden', (tester) async {
    await pumpCart(tester, const CartState(status: CartStatus.ready));
    await expectLater(
      find.byType(CartScreen),
      matchesGoldenFile('../../../../goldens/cart_empty.png'),
    );
  });

  testWidgets('loaded cart matches its golden', (tester) async {
    await pumpCart(
      tester,
      const CartState(
        status: CartStatus.ready,
        items: [
          CartItemModel(
            id: 'c1',
            productId: 'p1',
            productName: 'Premium Divan',
            productImage: '',
            productPrice: 4500000,
            quantity: 2,
          ),
        ],
      ),
    );
    await expectLater(
      find.byType(CartScreen),
      matchesGoldenFile('../../../../goldens/cart_loaded.png'),
    );
  });
}
