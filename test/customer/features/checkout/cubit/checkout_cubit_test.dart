import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/checkout/cubit/checkout_cubit.dart';
import 'package:woody_app/shared/models/cart.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';
import 'package:woody_app/shared/repositories/cart_repository.dart';
import 'package:woody_app/shared/repositories/checkout_repository.dart';
import 'package:woody_app/shared/repositories/payment_repository.dart';

class _MockCheckoutRepo extends Mock implements CheckoutRepository {}

class _MockCartRepo extends Mock implements CartRepository {}

class _MockPaymentRepo extends Mock implements PaymentRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const <CheckoutOrderLine>[]);
    registerFallbackValue(PaymentProvider.payme);
  });

  late _MockCheckoutRepo checkout;
  late _MockCartRepo cartRepo;
  late _MockPaymentRepo payments;

  setUp(() {
    checkout = _MockCheckoutRepo();
    cartRepo = _MockCartRepo();
    payments = _MockPaymentRepo();
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

  CheckoutCubit buildWithPayments({
    List<CartItemModel> items = const <CartItemModel>[],
  }) => CheckoutCubit(
    items: items,
    checkout: checkout,
    cartRepo: cartRepo,
    payments: payments,
  );

  const item = CartItemModel(
    id: 'c1',
    productId: 'p1',
    productName: 'Premium Divan',
    productImage: '',
    productPrice: 4500000,
    quantity: 1,
  );

  // A line that offers paid installation, used to exercise the toggle. No
  // shopId → it pools under the '' group key.
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

  // Two installable lines in two different shops, to prove the installation
  // opt-in is tracked per shop.
  const installItemA = CartItemModel(
    id: 'a1',
    productId: 'pa',
    productName: 'Stol',
    productImage: '',
    productPrice: 2000000,
    quantity: 1,
    shopId: 'shopA',
    shopName: 'Alfa',
    hasInstallation: true,
    installationPrice: 300000,
  );
  const installItemB = CartItemModel(
    id: 'b1',
    productId: 'pb',
    productName: 'Divan',
    productImage: '',
    productPrice: 3000000,
    quantity: 1,
    shopId: 'shopB',
    shopName: 'Beta',
    hasInstallation: true,
    installationPrice: 700000,
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
    act: (cubit) => cubit.selectPayment(CheckoutPayment.payme),
    expect: () => [
      isA<CheckoutState>().having(
        (s) => s.payment,
        'payment',
        CheckoutPayment.payme,
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
    'toggleInstallation adds the shop installation fee to the grand total',
    build: () => build(items: const [installItem]),
    // installItem has no shopId, so it pools under the '' group key.
    act: (cubit) => cubit.toggleInstallation('', true),
    expect: () => [
      isA<CheckoutState>()
          .having((s) => s.wantsInstallationFor(''), 'wants for shop', true)
          .having((s) => s.installationAvailable, 'available', true)
          // subtotal 1_000_000 + installation 500_000, no delivery.
          .having((s) => s.grandTotal, 'grandTotal', 1500000),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    "toggling one shop's installation leaves the other shop's total untouched",
    build: () => build(items: const [installItemA, installItemB]),
    act: (cubit) => cubit.toggleInstallation('shopA', true),
    expect: () => [
      isA<CheckoutState>()
          .having((s) => s.wantsInstallationFor('shopA'), 'A opted in', true)
          .having((s) => s.wantsInstallationFor('shopB'), 'B untouched', false)
          // shopA: 2_000_000 products + 300_000 installation.
          .having(
            (s) => s.groupTotal(
              s.groups.firstWhere((g) => g.shopId == 'shopA'),
            ),
            'shopA total',
            2300000,
          )
          // shopB: 3_000_000 products, installation NOT applied.
          .having(
            (s) => s.groupTotal(
              s.groups.firstWhere((g) => g.shopId == 'shopB'),
            ),
            'shopB total',
            3000000,
          )
          // Grand total = 5_000_000 products + only shopA's 300_000 install.
          .having((s) => s.grandTotal, 'grandTotal', 5300000),
    ],
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'submit places one order per shop, each with its own installation flag',
    build: () {
      when(
        () => checkout.placeOrder(
          lines: any(named: 'lines'),
          deliveryAddress: any(named: 'deliveryAddress'),
          wantInstallation: any(named: 'wantInstallation'),
        ),
      ).thenAnswer((_) async => 'order');
      when(() => cartRepo.clear()).thenAnswer((_) async => const Cart());
      return build(items: const [installItemA, installItemB]);
    },
    act: (cubit) {
      cubit.toggleInstallation('shopA', true);
      cubit.submit('user-1');
    },
    skip: 2, // the toggle emit + the submitting emit
    expect: () => [
      isA<CheckoutState>().having(
        (s) => s.status,
        'status',
        CheckoutStatus.success,
      ),
    ],
    verify: (_) {
      // shopA opted in → its order carries want_installation=true.
      verify(
        () => checkout.placeOrder(
          lines: any(named: 'lines'),
          deliveryAddress: any(named: 'deliveryAddress'),
          wantInstallation: true,
        ),
      ).called(1);
      // shopB never opted in → its order carries want_installation=false.
      verify(
        () => checkout.placeOrder(
          lines: any(named: 'lines'),
          deliveryAddress: any(named: 'deliveryAddress'),
          wantInstallation: false,
        ),
      ).called(1);
    },
  );

  // Deferred payment: an online order is placed WITHOUT minting a checkout
  // link. The payment_method is passed through (so seller-accept can branch);
  // the customer pays the final total from the order screen once the seller
  // sets the delivery fee.
  blocTest<CheckoutCubit, CheckoutState>(
    'payme order is placed deferred — no checkout link is minted',
    build: () {
      when(
        () => checkout.placeOrder(
          lines: any(named: 'lines'),
          deliveryAddress: any(named: 'deliveryAddress'),
          paymentMethod: any(named: 'paymentMethod'),
          wantInstallation: any(named: 'wantInstallation'),
        ),
      ).thenAnswer((_) async => 'order-1');
      when(() => cartRepo.clear()).thenAnswer((_) async => const Cart());
      return buildWithPayments(items: const [item]);
    },
    act: (cubit) {
      cubit.selectPayment(CheckoutPayment.payme);
      cubit.submit('user-1');
    },
    expect: () => [
      isA<CheckoutState>().having(
        (s) => s.payment,
        'payment',
        CheckoutPayment.payme,
      ),
      isA<CheckoutState>().having(
        (s) => s.status,
        'status',
        CheckoutStatus.submitting,
      ),
      isA<CheckoutState>()
          .having((s) => s.status, 'status', CheckoutStatus.success)
          .having((s) => s.placedOrderIds, 'orders', ['order-1'])
          // No link minted at checkout — deferred to the order screen.
          .having((s) => s.checkoutUrl, 'url', isNull),
    ],
    verify: (_) {
      // The chosen method rides on the order so the seller-accept can branch.
      verify(
        () => checkout.placeOrder(
          lines: any(named: 'lines'),
          deliveryAddress: any(named: 'deliveryAddress'),
          paymentMethod: 'payme',
          wantInstallation: any(named: 'wantInstallation'),
        ),
      ).called(1);
      // The deep-link is NEVER minted during checkout anymore.
      verifyNever(
        () => payments.checkoutUrl(
          orderId: any(named: 'orderId'),
          provider: any(named: 'provider'),
        ),
      );
    },
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
