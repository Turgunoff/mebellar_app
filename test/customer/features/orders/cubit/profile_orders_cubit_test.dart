import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/auth/auth_repository.dart';
import 'package:woody_app/core/network/woody_api_client.dart';
import 'package:woody_app/customer/features/orders/cubit/profile_orders_cubit.dart';

class _MockApi extends Mock implements WoodyApiClient {}

class _MockAuth extends Mock implements AuthRepository {}

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
      final api = _MockApi();
      final auth = _MockAuth();
      when(() => auth.isAuthenticated).thenReturn(false);
      return ProfileOrdersCubit(api, auth);
    },
    act: (cubit) => cubit.fetch(),
    expect: () => const <ProfileOrdersState>[],
  );
}
