import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/customer/features/orders/bloc/order_detail_bloc.dart';
import '../../../../fixtures/mocks/mock/mock_orders_data.dart';
import 'package:woody_app/shared/models/order.dart';
import 'package:woody_app/shared/repositories/order_repository.dart';

class _MockOrderRepo extends Mock implements OrderRepository {}

void main() {
  late _MockOrderRepo repo;
  final order = MockOrdersData.orders.first;

  setUp(() => repo = _MockOrderRepo());

  blocTest<OrderDetailBloc, OrderDetailState>(
    'OrderDetailRequested emits [loading, ready, realtime-connected]',
    build: () {
      when(() => repo.getById(order.id)).thenAnswer((_) async => order);
      when(() => repo.watch(order.id))
          .thenAnswer((_) => Stream<Order>.empty());
      return OrderDetailBloc(repo);
    },
    act: (bloc) => bloc.add(OrderDetailRequested(order.id)),
    expect: () => [
      isA<OrderDetailState>()
          .having((s) => s.status, 'status', OrderDetailStatus.loading),
      isA<OrderDetailState>()
          .having((s) => s.status, 'status', OrderDetailStatus.ready)
          .having((s) => s.order?.id, 'order', order.id),
      isA<OrderDetailState>()
          .having((s) => s.realtimeConnected, 'realtime', true),
    ],
  );

  blocTest<OrderDetailBloc, OrderDetailState>(
    'OrderDetailRequested emits [loading, failure] when the fetch throws',
    build: () {
      when(() => repo.getById(any())).thenThrow(Exception('order missing'));
      return OrderDetailBloc(repo);
    },
    act: (bloc) => bloc.add(const OrderDetailRequested('nope')),
    expect: () => [
      isA<OrderDetailState>()
          .having((s) => s.status, 'status', OrderDetailStatus.loading),
      isA<OrderDetailState>()
          .having((s) => s.status, 'status', OrderDetailStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<OrderDetailBloc, OrderDetailState>(
    'OrderDetailCancelled emits [mutating, ready] with the cancelled order',
    build: () {
      when(() => repo.cancel(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async => MockOrdersData.orders[2]);
      return OrderDetailBloc(repo);
    },
    seed: () => OrderDetailState(
      status: OrderDetailStatus.ready,
      order: order,
    ),
    act: (bloc) => bloc.add(const OrderDetailCancelled('changed my mind')),
    expect: () => [
      isA<OrderDetailState>()
          .having((s) => s.status, 'status', OrderDetailStatus.mutating),
      isA<OrderDetailState>()
          .having((s) => s.status, 'status', OrderDetailStatus.ready)
          .having((s) => s.order?.id, 'order', MockOrdersData.orders[2].id),
    ],
  );

  blocTest<OrderDetailBloc, OrderDetailState>(
    'OrderDetailCancelled surfaces the error but stays on the ready screen',
    build: () {
      when(() => repo.cancel(any(), reason: any(named: 'reason')))
          .thenThrow(Exception('cancel rejected'));
      return OrderDetailBloc(repo);
    },
    seed: () => OrderDetailState(
      status: OrderDetailStatus.ready,
      order: order,
    ),
    act: (bloc) => bloc.add(const OrderDetailCancelled('reason')),
    expect: () => [
      isA<OrderDetailState>()
          .having((s) => s.status, 'status', OrderDetailStatus.mutating),
      isA<OrderDetailState>()
          .having((s) => s.status, 'status', OrderDetailStatus.ready)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<OrderDetailBloc, OrderDetailState>(
    'OrderDetailCancelled is a no-op when no order is loaded',
    build: () => OrderDetailBloc(repo),
    act: (bloc) => bloc.add(const OrderDetailCancelled('reason')),
    expect: () => const <OrderDetailState>[],
  );
}
