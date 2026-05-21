import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/orders/bloc/orders_bloc.dart';
import '../../../../fixtures/mocks/mock/mock_order_repository.dart';
import 'package:woody_app/shared/models/order_status.dart';

void main() {
  group('OrdersBloc (mock repository)', () {
    blocTest<OrdersBloc, OrdersState>(
      'fetch -> seeds 3 orders from mock data',
      build: () => OrdersBloc(MockOrderRepository()),
      act: (bloc) => bloc.add(const OrdersRequested()),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(bloc.state.status, OrdersStatus.ready);
        expect(bloc.state.orders.length, greaterThanOrEqualTo(3));
      },
    );

    blocTest<OrdersBloc, OrdersState>(
      'tab change filters visible orders',
      build: () => OrdersBloc(MockOrderRepository()),
      act: (bloc) async {
        bloc.add(const OrdersRequested());
        await Future<void>.delayed(const Duration(milliseconds: 400));
        bloc.add(const OrdersTabChanged(OrdersTab.cancelled));
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.state.tab, OrdersTab.cancelled);
        // Every visible order in the cancelled tab is cancelled.
        expect(
          bloc.state.visibleOrders.every(
            (o) => o.status == OrderStatus.cancelled,
          ),
          isTrue,
        );
      },
    );
  });
}
