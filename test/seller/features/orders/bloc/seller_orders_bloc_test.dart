import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/error/failure.dart';
import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/seller/features/orders/bloc/seller_orders_bloc.dart';
import '../../../../fixtures/mocks/mock/mock_seller_order_repository.dart';
import 'package:woody_app/shared/models/order.dart';
import 'package:woody_app/shared/models/order_status.dart';

import '../fake_seller_order_repository.dart';
import '../order_fixtures.dart';

void main() {
  group('SellerOrdersBloc (fake repository)', () {
    late FakeSellerOrderRepository repo;

    setUp(() => repo = FakeSellerOrderRepository());
    tearDown(() => repo.dispose());

    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'load success populates orders + flips status to ready',
      build: () {
        repo.listResult = Ok([
          makeOrder(id: 'a', status: OrderStatus.pending),
          makeOrder(id: 'b', status: OrderStatus.shipped),
        ]);
        return SellerOrdersBloc(repo);
      },
      act: (bloc) => bloc.add(const SellerOrdersRequested()),
      expect: () => [
        // Loading frame
        const SellerOrdersState(status: SellerOrdersStatus.loading),
        // Ready frame with the two orders
        isA<SellerOrdersState>()
            .having((s) => s.status, 'status', SellerOrdersStatus.ready)
            .having((s) => s.orders.length, 'orders.length', 2),
      ],
      verify: (_) => expect(repo.listCalls, 1),
    );

    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'load failure surfaces failure.message',
      build: () {
        repo.listResult = const Err(ServerFailure(message: 'boom'));
        return SellerOrdersBloc(repo);
      },
      act: (bloc) => bloc.add(const SellerOrdersRequested()),
      expect: () => [
        const SellerOrdersState(status: SellerOrdersStatus.loading),
        const SellerOrdersState(
          status: SellerOrdersStatus.failure,
          error: 'boom',
        ),
      ],
    );

    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'tab change to non-new keeps unread set when no orders inserted',
      build: () => SellerOrdersBloc(repo),
      act: (bloc) =>
          bloc.add(const SellerOrdersTabChanged(SellerOrdersTab.active)),
      expect: () => [
        isA<SellerOrdersState>()
            .having((s) => s.tab, 'tab', SellerOrdersTab.active),
      ],
    );

    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'realtime new-order insert lands in state + bumps unread on non-new tab',
      build: () {
        repo.listResult = const Ok(<Order>[]);
        return SellerOrdersBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const SellerOrdersRequested());
        await Future<void>.delayed(Duration.zero);
        // Move off the new tab so the insert counts as unread.
        bloc.add(const SellerOrdersTabChanged(SellerOrdersTab.active));
        await Future<void>.delayed(Duration.zero);
        repo.emitNewOrder(makeOrder(id: 'fresh', status: OrderStatus.pending));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.orders.map((o) => o.id), contains('fresh'));
        expect(bloc.state.unreadNewIds, contains('fresh'));
        expect(bloc.state.badgeCount, 1);
      },
    );

    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'switching to new tab clears unread',
      build: () {
        repo.listResult = const Ok(<Order>[]);
        return SellerOrdersBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const SellerOrdersRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SellerOrdersTabChanged(SellerOrdersTab.active));
        await Future<void>.delayed(Duration.zero);
        repo.emitNewOrder(makeOrder(id: 'fresh'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SellerOrdersTabChanged(SellerOrdersTab.newTab));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.tab, SellerOrdersTab.newTab);
        expect(bloc.state.badgeCount, 0);
      },
    );

    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'duplicate realtime insert is deduplicated by order id',
      build: () {
        repo.listResult = const Ok(<Order>[]);
        return SellerOrdersBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const SellerOrdersRequested());
        await Future<void>.delayed(Duration.zero);
        repo.emitNewOrder(makeOrder(id: 'dupe'));
        repo.emitNewOrder(makeOrder(id: 'dupe'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.orders.where((o) => o.id == 'dupe').length, 1);
      },
    );

    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'realtime UPDATE replaces the existing row in place + clears unread on '
      'terminal transition',
      build: () {
        repo.listResult = Ok([
          makeOrder(id: 'live', status: OrderStatus.pending),
        ]);
        return SellerOrdersBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const SellerOrdersRequested());
        await Future<void>.delayed(Duration.zero);
        // Pretend we were on the active tab so the row was marked unread.
        bloc.add(const SellerOrdersTabChanged(SellerOrdersTab.active));
        await Future<void>.delayed(Duration.zero);
        // Push a realtime "fresh insert" into the unread set first.
        repo.emitNewOrder(makeOrder(id: 'live2', status: OrderStatus.pending));
        await Future<void>.delayed(Duration.zero);
        // Then have the server flip `live2` to delivered — the bloc should
        // update the row AND remove it from the unread set (terminal).
        repo.emitOrderUpdate(
          makeOrder(id: 'live2', status: OrderStatus.delivered),
        );
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        final live2 = bloc.state.orders.firstWhere((o) => o.id == 'live2');
        expect(live2.status, OrderStatus.delivered);
        expect(bloc.state.unreadNewIds, isNot(contains('live2')));
      },
    );

    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'pushOrderUpdate (from detail bloc) reflects in list immediately',
      build: () {
        repo.listResult = Ok([
          makeOrder(id: 'x', status: OrderStatus.pending),
        ]);
        return SellerOrdersBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const SellerOrdersRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.pushOrderUpdate(
          makeOrder(id: 'x', status: OrderStatus.confirmed),
        );
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(
          bloc.state.orders.firstWhere((o) => o.id == 'x').status,
          OrderStatus.confirmed,
        );
      },
    );

    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'tab filter exposes only orders matching the active bucket',
      build: () {
        repo.listResult = Ok([
          makeOrder(id: 'p1', status: OrderStatus.pending),
          makeOrder(id: 'c1', status: OrderStatus.confirmed),
          makeOrder(id: 'd1', status: OrderStatus.delivered),
          makeOrder(id: 'x1', status: OrderStatus.cancelled),
        ]);
        return SellerOrdersBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const SellerOrdersRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SellerOrdersTabChanged(SellerOrdersTab.done));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(
          bloc.state.visibleOrders.map((o) => o.id),
          ['d1'],
        );
      },
    );
  });

  group('SellerOrdersTab filter', () {
    test('newTab matches only pending', () {
      expect(
        SellerOrdersTab.newTab.matches(makeOrder(status: OrderStatus.pending)),
        isTrue,
      );
      expect(
        SellerOrdersTab.newTab
            .matches(makeOrder(status: OrderStatus.confirmed)),
        isFalse,
      );
    });

    test('active matches confirmed/preparing/shipped', () {
      for (final s in [
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.shipped,
      ]) {
        expect(
          SellerOrdersTab.active.matches(makeOrder(status: s)),
          isTrue,
          reason: '$s should be active',
        );
      }
    });

    test('done matches only delivered', () {
      expect(
        SellerOrdersTab.done
            .matches(makeOrder(status: OrderStatus.delivered)),
        isTrue,
      );
      expect(
        SellerOrdersTab.done.matches(makeOrder(status: OrderStatus.shipped)),
        isFalse,
      );
    });

    test('cancelled matches only cancelled', () {
      expect(
        SellerOrdersTab.cancelled
            .matches(makeOrder(status: OrderStatus.cancelled)),
        isTrue,
      );
    });
  });

  // Smoke-test the mock repository implementation still satisfies the bloc
  // contract — the mock backs the offline build, so the bloc must stay
  // compatible with both backends.
  group('SellerOrdersBloc (mock repository smoke)', () {
    blocTest<SellerOrdersBloc, SellerOrdersState>(
      'load against mock seeds at least one order',
      build: () => SellerOrdersBloc(MockSellerOrderRepository()),
      act: (bloc) => bloc.add(const SellerOrdersRequested()),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(bloc.state.status, SellerOrdersStatus.ready);
        expect(bloc.state.orders, isNotEmpty);
      },
    );
  });
}
