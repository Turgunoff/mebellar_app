import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:woody_app/customer/features/orders/cubit/profile_orders_cubit.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockGoTrue extends Mock implements GoTrueClient {}

void main() {
  test('derived counts classify order rows by status', () {
    final state = ProfileOrdersState(
      orders: [
        {'status': 'pending'},
        {'status': 'confirmed'},
        {'status': 'preparing'},
        {'status': 'shipped'},
        {'status': 'delivered'},
      ],
    );
    expect(state.pendingCount, 1);
    expect(state.processingCount, 2); // 'confirmed' + 'preparing'
    expect(state.deliveringCount, 1); // 'shipped'
    expect(state.hasActivity, isTrue);
  });

  test('hasActivity is false once every order is terminal', () {
    final state = ProfileOrdersState(
      orders: [
        {'status': 'delivered'},
        {'status': 'cancelled'},
      ],
    );
    expect(state.hasActivity, isFalse);
  });

  blocTest<ProfileOrdersCubit, ProfileOrdersState>(
    'fetch with no signed-in user is a no-op',
    build: () {
      final supabase = _MockSupabase();
      final auth = _MockGoTrue();
      when(() => supabase.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(null);
      return ProfileOrdersCubit(supabase);
    },
    act: (cubit) => cubit.fetch(),
    expect: () => const <ProfileOrdersState>[],
  );
}
