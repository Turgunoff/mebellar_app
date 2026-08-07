import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/seller/features/wallet/bloc/seller_wallet_cubit.dart';
import 'package:woody_app/shared/models/seller_wallet.dart';
import 'package:woody_app/shared/repositories/payment_repository.dart';
import 'package:woody_app/shared/repositories/seller_wallet_repository.dart';
import 'package:woody_app/shared/repositories/tariff_repository.dart';

class _MockWalletRepo extends Mock implements SellerWalletRepository {}

class _MockApi extends Mock implements WoodyApiClient {}

class _MockSettingsBox extends Mock implements Box {}

class _MockTariffRepo extends Mock implements TariffRepository {}

const _link = CheckoutLink(
  provider: 'payme',
  checkoutUrl: 'https://checkout.paycom.uz/abc',
  amount: 250000,
  reference: 'dep-1',
);

void main() {
  setUpAll(() => registerFallbackValue(PaymentProvider.payme));

  late _MockWalletRepo repo;
  late _MockApi api;
  late _MockSettingsBox settingsBox;
  late _MockTariffRepo tariff;

  SellerWalletCubit build() => SellerWalletCubit(
    repo,
    api: api,
    settingsBox: settingsBox,
    tariff: tariff,
  );

  setUp(() {
    repo = _MockWalletRepo();
    api = _MockApi();
    settingsBox = _MockSettingsBox();
    tariff = _MockTariffRepo();
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
      return build();
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
        () =>
            repo.createDeposit(amount: 250000, provider: PaymentProvider.payme),
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
      return build();
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
      return build();
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
    build: build,
    act: (cubit) => cubit.reconcileDeposit(),
    expect: () => const <SellerWalletState>[],
    verify: (_) {
      verifyNever(() => repo.depositStatus(any()));
      verifyNever(() => repo.fetch(recent: any(named: 'recent')));
    },
  );
}
