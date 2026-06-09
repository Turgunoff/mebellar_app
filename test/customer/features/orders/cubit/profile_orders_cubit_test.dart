import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/auth/auth_repository.dart';
import 'package:woody_app/customer/features/orders/cubit/profile_orders_cubit.dart';
import 'package:woody_app/shared/repositories/profile_orders_repository.dart';

// Mock the abstract repository, never WoodyApiClient — the cubit no longer
// depends on the network layer.
class _MockRepo extends Mock implements ProfileOrdersRepository {}

class _MockAuth extends Mock implements AuthRepository {}

// A raw woody_backend order row, the shape `fetchOrders()` returns.
Map<String, dynamic> _row(String id, String status) => {
      'id': id,
      'status': status,
      'total_amount': 100000,
      'created_at': '2026-01-01T00:00:00Z',
      'items': [
        {
          'quantity': 2,
          'product': {
            'name': 'Divan',
            'images': ['a.jpg'],
          },
        },
      ],
    };

void main() {
  late _MockRepo repo;
  late _MockAuth auth;

  setUp(() {
    repo = _MockRepo();
    auth = _MockAuth();
  });

  ProfileOrdersCubit build() => ProfileOrdersCubit(repo, auth);

  test('derived counts classify order rows by status', () {
    const state = ProfileOrdersState(
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
    const state = ProfileOrdersState(
      orders: [
        {'status': 'delivered'},
        {'status': 'cancelled'},
      ],
    );
    expect(state.hasActivity, isFalse);
  });

  blocTest<ProfileOrdersCubit, ProfileOrdersState>(
    'fetch is a no-op when signed out — never touches the repository',
    build: () {
      when(() => auth.isAuthenticated).thenReturn(false);
      return build();
    },
    act: (c) => c.fetch(),
    expect: () => const <ProfileOrdersState>[],
    verify: (_) => verifyNever(() => repo.fetchOrders()),
  );

  blocTest<ProfileOrdersCubit, ProfileOrdersState>(
    'fetch maps backend rows to card shape and exposes derived counts',
    build: () {
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => repo.fetchOrders()).thenAnswer(
        (_) async => [_row('o1', 'pending'), _row('o2', 'shipped')],
      );
      return build();
    },
    act: (c) => c.fetch(),
    expect: () => [
      isA<ProfileOrdersState>().having((s) => s.isLoading, 'isLoading', true),
      isA<ProfileOrdersState>()
          .having((s) => s.isLoading, 'isLoading', false)
          .having((s) => s.orders.length, 'orders', 2)
          .having((s) => s.pendingCount, 'pendingCount', 1)
          .having((s) => s.deliveringCount, 'deliveringCount', 1)
          .having((s) => s.hasActivity, 'hasActivity', true),
    ],
  );

  blocTest<ProfileOrdersCubit, ProfileOrdersState>(
    'fetch failure clears the spinner and keeps the list empty',
    build: () {
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => repo.fetchOrders()).thenThrow(Exception('boom'));
      return build();
    },
    act: (c) => c.fetch(),
    expect: () => [
      isA<ProfileOrdersState>().having((s) => s.isLoading, 'isLoading', true),
      isA<ProfileOrdersState>()
          .having((s) => s.isLoading, 'isLoading', false)
          .having((s) => s.orders, 'orders', isEmpty),
    ],
  );

  blocTest<ProfileOrdersCubit, ProfileOrdersState>(
    'cancelOrder calls the repo and patches the row to cancelled in place',
    build: () {
      when(() => repo.cancel(any(), any())).thenAnswer((_) async {});
      return build();
    },
    seed: () => const ProfileOrdersState(
      orders: [
        {'id': 'o1', 'status': 'pending'},
      ],
    ),
    act: (c) => c.cancelOrder('o1', 'changed mind'),
    expect: () => [
      isA<ProfileOrdersState>()
          .having((s) => s.orders.first['status'], 'status', 'cancelled')
          .having(
            (s) => s.orders.first['cancellation_reason'],
            'reason',
            'changed mind',
          ),
    ],
    verify: (_) => verify(() => repo.cancel('o1', 'changed mind')).called(1),
  );
}
