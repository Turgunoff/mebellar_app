import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/orders/bloc/seller_orders_bloc.dart';
import 'package:woody_app/shared/mock/mock_seller_order_repository.dart';
import 'package:woody_app/shared/models/order_status.dart';

void main() {
  group('SellerOrdersBloc (mock repository)', () {
    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'fetch -> seeded orders, defaults to "new" tab',
      build: () => SellerOrdersBloc(MockSellerOrderRepository()),
      act: (bloc) => bloc.add(const SellerOrdersRequested()),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(bloc.state.status, SellerOrdersStatus.ready);
        expect(bloc.state.tab, SellerOrdersTab.newTab);
        expect(bloc.state.orders.length, greaterThanOrEqualTo(3));
      },
    );

    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'tab change filters orders by status',
      build: () => SellerOrdersBloc(MockSellerOrderRepository()),
      act: (bloc) async {
        bloc.add(const SellerOrdersRequested());
        await Future<void>.delayed(const Duration(milliseconds: 400));
        bloc.add(const SellerOrdersTabChanged(SellerOrdersTab.cancelled));
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(
          bloc.state.visibleOrders
              .every((o) => o.status == OrderStatus.cancelled),
          isTrue,
        );
      },
    );

    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'switching to new tab clears the unread badge',
      build: () => SellerOrdersBloc(MockSellerOrderRepository()),
      act: (bloc) async {
        bloc.add(const SellerOrdersRequested());
        await Future<void>.delayed(const Duration(milliseconds: 400));
        // Move to active tab so the next inserted pending order pops up as unread.
        bloc.add(const SellerOrdersTabChanged(SellerOrdersTab.active));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        // Switch back to new tab — badge should clear.
        bloc.add(const SellerOrdersTabChanged(SellerOrdersTab.newTab));
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.state.tab, SellerOrdersTab.newTab);
        expect(bloc.state.badgeCount, 0);
      },
    );
  });
}
