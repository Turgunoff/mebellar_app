import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/seller/features/wallet/bloc/seller_wallet_cubit.dart';
import 'package:woody_app/shared/models/seller_wallet.dart';
import 'package:woody_app/shared/repositories/payment_repository.dart';
import 'package:woody_app/shared/repositories/seller_wallet_repository.dart';

class _MockWalletRepo extends Mock implements SellerWalletRepository {}

const _link = CheckoutLink(
  provider: 'payme',
  checkoutUrl: 'https://checkout.paycom.uz/abc',
  amount: 250000,
  reference: 'dep-1',
);

void main() {
  setUpAll(() => registerFallbackValue(PaymentProvider.payme));

  late _MockWalletRepo repo;

  setUp(() {
    repo = _MockWalletRepo();
    when(
      () => repo.fetch(recent: any(named: 'recent')),
    ).thenAnswer((_) async => const SellerWallet(balance: 5000));
  });

  blocTest<SellerWalletCubit, SellerWalletState>(
    'startDeposit creates the intent and returns the checkout link',
    build: () {
      when(
        () => repo.createDeposit(
          amount: any(named: 'amount'),
          provider: any(named: 'provider'),
        ),
      ).thenAnswer((_) async => _link);
      return SellerWalletCubit(repo);
    },
    act: (cubit) async {
      final result = await cubit.startDeposit(
        amount: 250000,
        provider: PaymentProvider.payme,
      );
      expect(result, _link);
    },
    expect: () => [
      isA<SellerWalletState>().having(
        (s) => s.depositStatus,
        'depositStatus',
        DepositStatus.starting,
      ),
      isA<SellerWalletState>().having(
        (s) => s.depositStatus,
        'depositStatus',
        DepositStatus.idle,
      ),
    ],
    verify: (_) {
      verify(
        () => repo.createDeposit(
          amount: 250000,
          provider: PaymentProvider.payme,
        ),
      ).called(1);
    },
  );

  blocTest<SellerWalletCubit, SellerWalletState>(
    'startDeposit failure surfaces DepositStatus.failure',
    build: () {
      when(
        () => repo.createDeposit(
          amount: any(named: 'amount'),
          provider: any(named: 'provider'),
        ),
      ).thenThrow(Exception('boom'));
      return SellerWalletCubit(repo);
    },
    act: (cubit) =>
        cubit.startDeposit(amount: 1000, provider: PaymentProvider.click),
    expect: () => [
      isA<SellerWalletState>().having(
        (s) => s.depositStatus,
        'depositStatus',
        DepositStatus.starting,
      ),
      isA<SellerWalletState>().having(
        (s) => s.depositStatus,
        'depositStatus',
        DepositStatus.failure,
      ),
    ],
  );

  blocTest<SellerWalletCubit, SellerWalletState>(
    'reconcileDeposit refreshes the balance once the deposit settles paid',
    build: () {
      when(
        () => repo.createDeposit(
          amount: any(named: 'amount'),
          provider: any(named: 'provider'),
        ),
      ).thenAnswer((_) async => _link);
      when(() => repo.depositStatus('dep-1')).thenAnswer((_) async => 'paid');
      return SellerWalletCubit(repo);
    },
    act: (cubit) async {
      await cubit.startDeposit(amount: 250000, provider: PaymentProvider.payme);
      await cubit.reconcileDeposit();
    },
    verify: (_) {
      verify(() => repo.depositStatus('dep-1')).called(1);
      // The paid status triggers exactly one balance reload.
      verify(() => repo.fetch(recent: any(named: 'recent'))).called(1);
    },
  );

  blocTest<SellerWalletCubit, SellerWalletState>(
    'reconcileDeposit is a no-op with nothing in flight',
    build: () => SellerWalletCubit(repo),
    act: (cubit) => cubit.reconcileDeposit(),
    expect: () => const <SellerWalletState>[],
    verify: (_) {
      verifyNever(() => repo.depositStatus(any()));
      verifyNever(() => repo.fetch(recent: any(named: 'recent')));
    },
  );
}
