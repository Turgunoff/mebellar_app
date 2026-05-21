import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:woody_app/customer/features/checkout/cubit/checkout_cubit.dart';
import 'package:woody_app/shared/models/cart_item_model.dart';
import 'package:woody_app/shared/repositories/cart_repository.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockCartRepo extends Mock implements CartRepository {}

void main() {
  late _MockSupabase supabase;
  late _MockCartRepo cartRepo;

  setUp(() {
    supabase = _MockSupabase();
    cartRepo = _MockCartRepo();
  });

  CheckoutCubit build() => CheckoutCubit(
        items: const <CartItemModel>[],
        supabase: supabase,
        cartRepo: cartRepo,
      );

  test('grandTotal equals subtotal — delivery is quoted by seller after placement', () {
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
      isA<CheckoutState>()
          .having((s) => s.payment, 'payment', CheckoutPayment.card),
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
    'submit emits [submitting, failure] when the order insert fails',
    build: () {
      when(() => supabase.from(any())).thenThrow(Exception('db unreachable'));
      return build();
    },
    act: (cubit) => cubit.submit('user-1'),
    expect: () => [
      isA<CheckoutState>()
          .having((s) => s.status, 'status', CheckoutStatus.submitting),
      isA<CheckoutState>()
          .having((s) => s.status, 'status', CheckoutStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );
}
