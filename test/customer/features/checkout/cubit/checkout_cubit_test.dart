import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/checkout/cubit/checkout_cubit.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';
import 'package:woody_app/shared/repositories/cart_repository.dart';
import 'package:woody_app/shared/repositories/checkout_repository.dart';

class _MockCheckoutRepo extends Mock implements CheckoutRepository {}

class _MockCartRepo extends Mock implements CartRepository {}

void main() {
  setUpAll(() => registerFallbackValue(const <CheckoutOrderLine>[]));

  late _MockCheckoutRepo checkout;
  late _MockCartRepo cartRepo;

  setUp(() {
    checkout = _MockCheckoutRepo();
    cartRepo = _MockCartRepo();
  });

  CheckoutCubit build({List<CartItemModel> items = const <CartItemModel>[]}) =>
      CheckoutCubit(items: items, checkout: checkout, cartRepo: cartRepo);

  const item = CartItemModel(
    id: 'c1',
    productId: 'p1',
    productName: 'Premium Divan',
    productImage: '',
    productPrice: 4500000,
    quantity: 1,
  );

  test(
    'grandTotal equals subtotal — delivery is quoted by seller after placement',
    () {
      const state = CheckoutState();
      expect(state.subtotal, 0);
      expect(state.grandTotal, 0);
      expect(state.hasAddress, isFalse);
    },
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'selectPayment switches the payment method',
    build: build,
    act: (cubit) => cubit.selectPayment(CheckoutPayment.card),
    expect: () => [
      isA<CheckoutState>().having(
        (s) => s.payment,
        'payment',
        CheckoutPayment.card,
      ),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'updateAddress trims and stores the delivery address',
    build: build,
    act: (cubit) => cubit.updateAddress('  Tashkent, Chilonzor  '),
    expect: () => [
      isA<CheckoutState>()
          .having((s) => s.deliveryAddress, 'address', 'Tashkent, Chilonzor')
          .having((s) => s.hasAddress, 'hasAddress', true),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'submit emits [submitting, failure] when the order POST fails',
    build: () {
      when(
        () => checkout.placeOrder(
          lines: any(named: 'lines'),
          deliveryAddress: any(named: 'deliveryAddress'),
        ),
      ).thenThrow(Exception('backend unreachable'));
      return build(items: const [item]);
    },
    act: (cubit) => cubit.submit('user-1'),
    expect: () => [
      isA<CheckoutState>().having(
        (s) => s.status,
        'status',
        CheckoutStatus.submitting,
      ),
      isA<CheckoutState>()
          .having((s) => s.status, 'status', CheckoutStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );
}
