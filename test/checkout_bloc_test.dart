import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/checkout/bloc/checkout_bloc.dart';
import 'package:woody_app/shared/models/order.dart';
import 'package:woody_app/shared/repositories/address_repository.dart';
import 'package:woody_app/shared/repositories/cart_repository.dart';
import 'package:woody_app/shared/repositories/order_repository.dart';

class _MockOrderRepo extends Mock implements OrderRepository {}

class _MockAddressRepo extends Mock implements AddressRepository {}

class _MockCartRepo extends Mock implements CartRepository {}

void main() {
  late _MockOrderRepo orderRepo;
  late _MockAddressRepo addressRepo;
  late _MockCartRepo cartRepo;

  setUp(() {
    orderRepo = _MockOrderRepo();
    addressRepo = _MockAddressRepo();
    cartRepo = _MockCartRepo();
  });

  CheckoutBloc build() => CheckoutBloc(
        orderRepo: orderRepo,
        addressRepo: addressRepo,
        cartRepo: cartRepo,
      );

  blocTest<CheckoutBloc, CheckoutState>(
    'CheckoutPaymentSelected updates the payment method',
    build: build,
    act: (bloc) =>
        bloc.add(const CheckoutPaymentSelected(OrderPaymentMethod.card)),
    expect: () => [
      isA<CheckoutState>()
          .having((s) => s.paymentMethod, 'payment', OrderPaymentMethod.card),
    ],
  );

  blocTest<CheckoutBloc, CheckoutState>(
    'CheckoutDeliveryMethodSelected records the method per shop',
    build: build,
    act: (bloc) => bloc.add(
      const CheckoutDeliveryMethodSelected(
        shopId: 'shop-1',
        method: OrderDeliveryMethod.pickup,
      ),
    ),
    expect: () => [
      isA<CheckoutState>().having(
        (s) => s.deliveryByShop['shop-1'],
        'delivery for shop-1',
        OrderDeliveryMethod.pickup,
      ),
    ],
  );

  blocTest<CheckoutBloc, CheckoutState>(
    'CheckoutPreviousStep is a no-op on the first step',
    build: build,
    act: (bloc) => bloc.add(const CheckoutPreviousStep()),
    expect: () => const <CheckoutState>[],
  );

  blocTest<CheckoutBloc, CheckoutState>(
    'CheckoutNextStep is blocked while the cart is empty',
    build: build,
    act: (bloc) => bloc.add(const CheckoutNextStep()),
    // canAdvanceFrom(review) requires a non-empty cart — the guard holds.
    expect: () => const <CheckoutState>[],
  );
}
