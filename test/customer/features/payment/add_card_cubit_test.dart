import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/payment/cubit/add_card_cubit.dart';
import 'package:woody_app/core/network/payme_client.dart';
import 'package:woody_app/shared/repositories/payment_cards_repository.dart';

class _MockPayme extends Mock implements PaymeClient {}

class _MockCardsRepo extends Mock implements PaymentCardsRepository {}

PaymeCard _verifiedCard() => const PaymeCard(
  token: 'tok-final',
  maskedNumber: '860006******6311',
  recurrent: true,
  verify: true,
);

void main() {
  late _MockPayme payme;
  late _MockCardsRepo repo;

  setUp(() {
    payme = _MockPayme();
    repo = _MockCardsRepo();
  });

  AddCardCubit build() => AddCardCubit(payme: payme, repo: repo);

  blocTest<AddCardCubit, AddCardState>(
    'startCard tokenises, requests the SMS, and moves to the code step',
    build: () {
      when(() => payme.createCard(
            number: any(named: 'number'),
            expire: any(named: 'expire'),
          )).thenAnswer((_) async => const PaymeCard(
            token: 'tok-1',
            maskedNumber: '860006******6311',
            recurrent: true,
            verify: false,
          ));
      when(() => payme.getVerifyCode(any())).thenAnswer(
        (_) async => const PaymeVerifyChallenge(phone: '99890*****31', waitMs: 60000),
      );
      return build();
    },
    act: (c) => c.startCard(number: '8600 0691 9540 6311', expire: '03/99'),
    expect: () => [
      isA<AddCardState>().having((s) => s.submitting, 'submitting', true),
      isA<AddCardState>()
          .having((s) => s.step, 'step', AddCardStep.code)
          .having((s) => s.submitting, 'submitting', false)
          .having((s) => s.token, 'token', 'tok-1')
          .having((s) => s.maskedPhone, 'phone', '99890*****31'),
    ],
    verify: (_) {
      // Card digits are normalised before reaching Payme (no spaces, MMYY).
      verify(() => payme.createCard(number: '8600069195406311', expire: '0399'))
          .called(1);
    },
  );

  blocTest<AddCardCubit, AddCardState>(
    'startCard surfaces a Payme error and stays on the form',
    build: () {
      when(() => payme.createCard(
            number: any(named: 'number'),
            expire: any(named: 'expire'),
          )).thenThrow(PaymeException('bad card', code: -31300));
      return build();
    },
    act: (c) => c.startCard(number: '8600000000000000', expire: '0399'),
    expect: () => [
      isA<AddCardState>().having((s) => s.submitting, 'submitting', true),
      isA<AddCardState>()
          .having((s) => s.step, 'step', AddCardStep.form)
          .having((s) => s.submitting, 'submitting', false)
          .having((s) => s.error, 'error', 'bad card'),
    ],
  );

  blocTest<AddCardCubit, AddCardState>(
    'submitCode verifies, persists on the backend, and finishes',
    build: () {
      when(() => payme.verifyCard(
            token: any(named: 'token'),
            code: any(named: 'code'),
          )).thenAnswer((_) async => _verifiedCard());
      when(() => repo.add(
            token: any(named: 'token'),
            maskedNumber: any(named: 'maskedNumber'),
          )).thenAnswer((_) async => SavedCard(
            id: 'c1',
            maskedNumber: '860006******6311',
            isActive: true,
          ));
      return build();
    },
    seed: () => const AddCardState(step: AddCardStep.code, token: 'tok-1'),
    act: (c) => c.submitCode('666666'),
    expect: () => [
      isA<AddCardState>().having((s) => s.submitting, 'submitting', true),
      isA<AddCardState>()
          .having((s) => s.step, 'step', AddCardStep.done)
          .having((s) => s.submitting, 'submitting', false),
    ],
    verify: (_) {
      verify(() => repo.add(token: 'tok-final', maskedNumber: '860006******6311'))
          .called(1);
    },
  );

  blocTest<AddCardCubit, AddCardState>(
    'submitCode surfaces a wrong-code error without persisting',
    build: () {
      when(() => payme.verifyCard(
            token: any(named: 'token'),
            code: any(named: 'code'),
          )).thenThrow(PaymeException('wrong code', code: -31301));
      return build();
    },
    seed: () => const AddCardState(step: AddCardStep.code, token: 'tok-1'),
    act: (c) => c.submitCode('000000'),
    expect: () => [
      isA<AddCardState>().having((s) => s.submitting, 'submitting', true),
      isA<AddCardState>()
          .having((s) => s.step, 'step', AddCardStep.code)
          .having((s) => s.submitting, 'submitting', false)
          .having((s) => s.error, 'error', 'wrong code'),
    ],
    verify: (_) => verifyNever(() => repo.add(
          token: any(named: 'token'),
          maskedNumber: any(named: 'maskedNumber'),
        )),
  );
}
