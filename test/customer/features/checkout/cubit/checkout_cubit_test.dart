import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/checkout/cubit/checkout_cubit.dart';
import 'package:woody_app/shared/models/cart.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';
import 'package:woody_app/shared/repositories/cart_repository.dart';
import 'package:woody_app/shared/repositories/checkout_repository.dart';
import 'package:woody_app/shared/repositories/payment_cards_repository.dart';

class _MockCheckoutRepo extends Mock implements CheckoutRepository {}

class _MockCartRepo extends Mock implements CartRepository {}

class _MockCardsRepo extends Mock implements PaymentCardsRepository {}

void main() {
  setUpAll(() => registerFallbackValue(const <CheckoutOrderLine>[]));

  late _MockCheckoutRepo checkout;
  late _MockCartRepo cartRepo;
  late _MockCardsRepo cardsRepo;

  setUp(() {
    checkout = _MockCheckoutRepo();
    cartRepo = _MockCartRepo();
    cardsRepo = _MockCardsRepo();
    // Default: the construction-time quote refresh is a no-op (swallowed),
    // so tests that don't care about quoting stay deterministic.
    when(
      () => checkout.quote(
        lines: any(named: 'lines'),
        deliveryAddress: any(named: 'deliveryAddress'),
        wantInstallation: any(named: 'wantInstallation'),
      ),
    ).thenThrow(Exception('quote disabled in test'));
  });

  CheckoutCubit build({List<CartItemModel> items = const <CartItemModel>[]}) =>
      CheckoutCubit(items: items, checkout: checkout, cartRepo: cartRepo);

  CheckoutCubit buildWithCards({
    List<CartItemModel> items = const <CartItemModel>[],
  }) => CheckoutCubit(
    items: items,
    checkout: checkout,
    cartRepo: cartRepo,
    cards: cardsRepo,
  );

  const item = CartItemModel(
    id: 'c1',
    productId: 'p1',
    productName: 'Premium Divan',
    productImage: '',
    productPrice: 4500000,
    quantity: 1,
  );

  // A line that offers paid installation, used to exercise the toggle.
  const installItem = CartItemModel(
    id: 'c2',
    productId: 'p2',
    productName: 'Shkaf',
    productImage: '',
    productPrice: 1000000,
    quantity: 1,
    hasInstallation: true,
    installationPrice: 500000,
  );

  test('grandTotal equals subtotal when there are no fees', () {
    const state = CheckoutState();
    expect(state.subtotal, 0);
    expect(state.grandTotal, 0);
    expect(state.hasAddress, isFalse);
  });

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
          wantInstallation: any(named: 'wantInstallation'),
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

  blocTest<CheckoutCubit, CheckoutState>(
    'toggleInstallation adds the installation fee to the grand total',
    build: () => build(items: const [installItem]),
    act: (cubit) => cubit.toggleInstallation(true),
    expect: () => [
      isA<CheckoutState>()
          .having((s) => s.wantsInstallation, 'wantsInstallation', true)
          .having((s) => s.installationAvailable, 'available', true)
          // subtotal 1_000_000 + installation 500_000, no delivery.
          .having((s) => s.grandTotal, 'grandTotal', 1500000),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'selectCard flips the method to card and stores the chosen card',
    build: build,
    act: (cubit) => cubit.selectCard('card-1'),
    expect: () => [
      isA<CheckoutState>()
          .having((s) => s.payment, 'payment', CheckoutPayment.card)
          .having((s) => s.selectedCardId, 'card', 'card-1')
          .having((s) => s.isCardPayment, 'isCardPayment', true),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'card payment places then charges each order with the chosen card',
    build: () {
      when(
        () => checkout.placeOrder(
          lines: any(named: 'lines'),
          deliveryAddress: any(named: 'deliveryAddress'),
          wantInstallation: any(named: 'wantInstallation'),
        ),
      ).thenAnswer((_) async => 'order-1');
      when(() => cartRepo.clear()).thenAnswer((_) async => const Cart());
      when(
        () => cardsRepo.payOrder(
          orderId: any(named: 'orderId'),
          cardId: any(named: 'cardId'),
        ),
      ).thenAnswer(
        (_) async =>
            const OrderPayResult(paymentStatus: 'paid', provider: 'payme'),
      );
      return buildWithCards(items: const [item]);
    },
    act: (cubit) {
      cubit.selectCard('card-1');
      cubit.submit('user-1');
    },
    expect: () => [
      isA<CheckoutState>().having((s) => s.selectedCardId, 'card', 'card-1'),
      isA<CheckoutState>()
          .having((s) => s.status, 'status', CheckoutStatus.submitting),
      isA<CheckoutState>()
          .having((s) => s.status, 'status', CheckoutStatus.success)
          .having((s) => s.placedOrderIds, 'orders', ['order-1']),
    ],
    verify: (_) {
      verify(() => cardsRepo.payOrder(orderId: 'order-1', cardId: 'card-1'))
          .called(1);
    },
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'card payment emits failure when the charge is declined',
    build: () {
      when(
        () => checkout.placeOrder(
          lines: any(named: 'lines'),
          deliveryAddress: any(named: 'deliveryAddress'),
          wantInstallation: any(named: 'wantInstallation'),
        ),
      ).thenAnswer((_) async => 'order-1');
      when(() => cartRepo.clear()).thenAnswer((_) async => const Cart());
      when(
        () => cardsRepo.payOrder(
          orderId: any(named: 'orderId'),
          cardId: any(named: 'cardId'),
        ),
      ).thenThrow(Exception('declined'));
      return buildWithCards(items: const [item]);
    },
    act: (cubit) {
      cubit.selectCard('card-1');
      cubit.submit('user-1');
    },
    expect: () => [
      isA<CheckoutState>().having((s) => s.selectedCardId, 'card', 'card-1'),
      isA<CheckoutState>()
          .having((s) => s.status, 'status', CheckoutStatus.submitting),
      isA<CheckoutState>()
          .having((s) => s.status, 'status', CheckoutStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'merges the server quote into the invoice on construction',
    build: () {
      when(
        () => checkout.quote(
          lines: any(named: 'lines'),
          deliveryAddress: any(named: 'deliveryAddress'),
          wantInstallation: any(named: 'wantInstallation'),
        ),
      ).thenAnswer(
        (_) async => const CheckoutQuote(
          subtotal: 1000000,
          deliveryFee: 300000,
          installationFee: 500000,
          installationAvailable: true,
          grandTotal: 1300000,
        ),
      );
      return build(items: const [installItem]);
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<CheckoutState>()
          .having((s) => s.deliveryFee, 'deliveryFee', 300000)
          .having((s) => s.installationFee, 'installationFee', 500000)
          .having((s) => s.installationAvailable, 'available', true),
    ],
  );
}
