import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/error/failure.dart';
import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/seller/features/orders/bloc/seller_order_detail_bloc.dart';
import 'package:woody_app/shared/models/order.dart';
import 'package:woody_app/shared/models/order_status.dart';
import 'package:woody_app/shared/repositories/seller_order_repository.dart';

import '../fake_seller_order_repository.dart';
import '../order_fixtures.dart';

void main() {
  group('SellerOrderTransitions', () {
    test('forward transitions match the spec', () {
      expect(OrderStatus.pending.sellerForwardTransitions,
          [OrderStatus.confirmed]);
      expect(OrderStatus.confirmed.sellerForwardTransitions,
          [OrderStatus.preparing, OrderStatus.shipped]);
      expect(OrderStatus.preparing.sellerForwardTransitions,
          [OrderStatus.shipped]);
      expect(OrderStatus.shipped.sellerForwardTransitions,
          [OrderStatus.delivered]);
      expect(OrderStatus.delivered.sellerForwardTransitions, isEmpty);
      expect(OrderStatus.cancelled.sellerForwardTransitions, isEmpty);
    });
  });

  group('SellerOrderDetailBloc (fake repository)', () {
    late FakeSellerOrderRepository repo;

    setUp(() {
      repo = FakeSellerOrderRepository();
      // Default getById: return a freshly cloned pending order for any id.
      repo.getByIdResult = (id) => Ok(makeOrder(id: id));
    });

    tearDown(() => repo.dispose());

    blocTest<SellerOrderDetailBloc, SellerOrderDetailState>(
      'load success exposes the order',
      build: () => SellerOrderDetailBloc(repo),
      act: (bloc) => bloc.add(const SellerOrderDetailRequested('o1')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.status, SellerOrderDetailStatus.ready);
        expect(bloc.state.order?.id, 'o1');
        expect(bloc.state.canCancel, isTrue);
      },
    );

    blocTest<SellerOrderDetailBloc, SellerOrderDetailState>(
      'load failure surfaces the failure message',
      build: () {
        repo.getByIdResult =
            (_) => const Err(ServerFailure(message: 'not found'));
        return SellerOrderDetailBloc(repo);
      },
      act: (bloc) => bloc.add(const SellerOrderDetailRequested('missing')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.status, SellerOrderDetailStatus.failure);
        expect(bloc.state.error, 'not found');
      },
    );

    blocTest<SellerOrderDetailBloc, SellerOrderDetailState>(
      'confirm transitions pending -> confirmed and fires onUpdated',
      build: () => SellerOrderDetailBloc(
        repo,
        // Write straight into the test-scoped static — verify() reads it
        // back after `act` has run. A closure-local variable would be
        // hidden inside the build callback's frame.
        onUpdated: (o) => _CapturedUpdate.value = o,
      ),
      act: (bloc) async {
        _CapturedUpdate.value = null;
        bloc.add(const SellerOrderDetailRequested('p1'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const SellerOrderActionConfirmed());
      },
      wait: const Duration(milliseconds: 30),
      verify: (bloc) {
        expect(bloc.state.order?.status, OrderStatus.confirmed);
        expect(repo.confirmCalls, 1);
        expect(_CapturedUpdate.value?.status, OrderStatus.confirmed);
      },
    );

    blocTest<SellerOrderDetailBloc, SellerOrderDetailState>(
      'cancel records the reason and moves status to cancelled',
      build: () => SellerOrderDetailBloc(repo),
      act: (bloc) async {
        bloc.add(const SellerOrderDetailRequested('c1'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const SellerOrderActionCancelled('Mahsulot tugadi'));
      },
      wait: const Duration(milliseconds: 30),
      verify: (bloc) {
        expect(bloc.state.order?.status, OrderStatus.cancelled);
        expect(bloc.state.order?.cancelReason, 'Mahsulot tugadi');
        expect(repo.cancelCalls, 1);
      },
    );

    blocTest<SellerOrderDetailBloc, SellerOrderDetailState>(
      'realtime watch update mutates the loaded order in place',
      build: () => SellerOrderDetailBloc(repo),
      act: (bloc) async {
        bloc.add(const SellerOrderDetailRequested('w1'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        // Push a realtime update — bloc subscribes to repo.watch(id) when
        // the load resolves.
        repo.emitOrderUpdate(
          makeOrder(id: 'w1', status: OrderStatus.shipped),
        );
      },
      wait: const Duration(milliseconds: 30),
      verify: (bloc) {
        expect(bloc.state.order?.status, OrderStatus.shipped);
      },
    );

    blocTest<SellerOrderDetailBloc, SellerOrderDetailState>(
      'failed transition keeps the order intact and surfaces the message',
      build: () => SellerOrderDetailBloc(repo),
      act: (bloc) async {
        bloc.add(const SellerOrderDetailRequested('f1'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        // Swap in a builder that always rejects, then attempt to confirm.
        repo.getByIdResult =
            (_) => const Err(ServerFailure(message: 'denied'));
        bloc.add(const SellerOrderActionConfirmed());
      },
      wait: const Duration(milliseconds: 30),
      verify: (bloc) {
        // The mutation surfaces the error, but the previously loaded order
        // stays put so the screen doesn't blank out.
        expect(bloc.state.status, SellerOrderDetailStatus.ready);
        expect(bloc.state.error, 'denied');
        expect(bloc.state.order?.id, 'f1');
      },
    );
  });
}

/// Test-scoped capture for the `onUpdated` callback. Lives outside the
/// bloc so the `verify` block can read what the callback observed in the
/// preceding `act` phase without leaking state across groups.
class _CapturedUpdate {
  static Order? value;
}
