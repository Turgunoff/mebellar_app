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
    'payme payment places the order then mints a checkout deep-link',
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
        () => payments.checkoutUrl(
          orderId: any(named: 'orderId'),
          provider: any(named: 'provider'),
        ),
      ).thenAnswer(
        (_) async => const CheckoutLink(
          provider: 'payme',
          checkoutUrl: 'https://checkout.paycom.uz/x',
          amount: 4500000,
        ),
      );
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
          .having((s) => s.checkoutUrl, 'url', 'https://checkout.paycom.uz/x'),
    ],
    verify: (_) {
      verify(
        () => payments.checkoutUrl(
          orderId: 'order-1',
          provider: PaymentProvider.payme,
        ),
      ).called(1);
    },
  );

  blocTest<CheckoutCubit, CheckoutState>(
    'payme order still succeeds when the checkout link cannot be minted',
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
        () => payments.checkoutUrl(
          orderId: any(named: 'orderId'),
          provider: any(named: 'provider'),
        ),
      ).thenThrow(Exception('provider unavailable'));
      return buildWithPayments(items: const [item]);
    },
    act: (cubit) {
      cubit.selectPayment(CheckoutPayment.click);
      cubit.submit('user-1');
    },
    expect: () => [
      isA<CheckoutState>().having(
        (s) => s.payment,
        'payment',
        CheckoutPayment.click,
      ),
      isA<CheckoutState>().having(
        (s) => s.status,
        'status',
        CheckoutStatus.submitting,
      ),
      // The order is placed (success); only the convenience link is missing.
      isA<CheckoutState>()
          .having((s) => s.status, 'status', CheckoutStatus.success)
          .having((s) => s.placedOrderIds, 'orders', ['order-1'])
          .having((s) => s.checkoutUrl, 'url', isNull),
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
