import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/payment/cubit/payment_cards_cubit.dart';
import 'package:woody_app/shared/repositories/payment_cards_repository.dart';

class _MockCardsRepo extends Mock implements PaymentCardsRepository {}

SavedCard _card(String id) =>
    SavedCard(id: id, maskedNumber: '860006******$id', isActive: true);

void main() {
  late _MockCardsRepo repo;

  setUp(() => repo = _MockCardsRepo());

  blocTest<PaymentCardsCubit, PaymentCardsState>(
    'load emits [loading, ready] with the fetched cards',
    build: () {
      when(repo.list).thenAnswer((_) async => [_card('0001'), _card('0002')]);
      return PaymentCardsCubit(repo);
    },
    act: (c) => c.load(),
    expect: () => [
      isA<PaymentCardsState>()
          .having((s) => s.status, 'status', PaymentCardsStatus.loading),
      isA<PaymentCardsState>()
          .having((s) => s.status, 'status', PaymentCardsStatus.ready)
          .having((s) => s.cards.length, 'cards', 2),
    ],
  );

  blocTest<PaymentCardsCubit, PaymentCardsState>(
    'load emits [loading, failure] when the repo throws',
    build: () {
      when(repo.list).thenThrow(Exception('down'));
      return PaymentCardsCubit(repo);
    },
    act: (c) => c.load(),
    expect: () => [
      isA<PaymentCardsState>()
          .having((s) => s.status, 'status', PaymentCardsStatus.loading),
      isA<PaymentCardsState>()
          .having((s) => s.status, 'status', PaymentCardsStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<PaymentCardsCubit, PaymentCardsState>(
    'remove optimistically drops the card and keeps it gone on success',
    build: () {
      when(() => repo.remove(any())).thenAnswer((_) async {});
      return PaymentCardsCubit(repo);
    },
    seed: () => PaymentCardsState(
      status: PaymentCardsStatus.ready,
      cards: [_card('0001'), _card('0002')],
    ),
    act: (c) => c.remove('0001'),
    expect: () => [
      isA<PaymentCardsState>()
          .having((s) => s.cards.map((e) => e.id), 'ids', ['0002']),
    ],
    verify: (_) => verify(() => repo.remove('0001')).called(1),
  );

  blocTest<PaymentCardsCubit, PaymentCardsState>(
    'remove restores the card and surfaces an error on failure',
    build: () {
      when(() => repo.remove(any())).thenThrow(Exception('nope'));
      return PaymentCardsCubit(repo);
    },
    seed: () => PaymentCardsState(
      status: PaymentCardsStatus.ready,
      cards: [_card('0001'), _card('0002')],
    ),
    act: (c) => c.remove('0001'),
    expect: () => [
      // optimistic drop
      isA<PaymentCardsState>()
          .having((s) => s.cards.length, 'cards', 1),
      // rollback + error
      isA<PaymentCardsState>()
          .having((s) => s.cards.length, 'cards', 2)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );
}
