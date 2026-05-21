import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/seller/features/dashboard/bloc/dashboard_bloc.dart';
import '../../../../fixtures/mocks/mock/mock_orders_data.dart';
import 'package:woody_app/shared/models/dashboard_snapshot.dart';
import 'package:woody_app/shared/models/order.dart';
import 'package:woody_app/shared/models/tariff.dart';
import 'package:woody_app/shared/repositories/seller_dashboard_repository.dart';

class _MockDashboardRepo extends Mock implements SellerDashboardRepository {}

DashboardSnapshot _snapshot() => const DashboardSnapshot(
      todaysOrders: 3,
      todaysRevenue: 500000,
      pendingOrdersCount: 2,
      activeProductsCount: 7,
      tariff: TariffSnapshot(plan: TariffPlan.free, activeProductsCount: 7),
      recentOrders: [],
      last30Days: [],
    );

void main() {
  late _MockDashboardRepo repo;

  setUp(() {
    repo = _MockDashboardRepo();
    // The bloc subscribes to newOrders() in its constructor.
    when(() => repo.newOrders()).thenAnswer((_) => Stream<Order>.empty());
  });

  blocTest<DashboardBloc, DashboardState>(
    'DashboardRequested emits [loading, ready] with the snapshot',
    build: () {
      when(repo.snapshot).thenAnswer((_) async => _snapshot());
      return DashboardBloc(repo);
    },
    act: (bloc) => bloc.add(const DashboardRequested()),
    expect: () => [
      isA<DashboardState>()
          .having((s) => s.status, 'status', DashboardStatus.loading),
      isA<DashboardState>()
          .having((s) => s.status, 'status', DashboardStatus.ready)
          .having((s) => s.snapshot?.todaysOrders, 'todaysOrders', 3),
    ],
  );

  blocTest<DashboardBloc, DashboardState>(
    'DashboardRequested emits [loading, failure] when the repo throws',
    build: () {
      when(repo.snapshot)
          .thenAnswer((_) async => throw Exception('snapshot down'));
      return DashboardBloc(repo);
    },
    act: (bloc) => bloc.add(const DashboardRequested()),
    expect: () => [
      isA<DashboardState>()
          .having((s) => s.status, 'status', DashboardStatus.loading),
      isA<DashboardState>()
          .having((s) => s.status, 'status', DashboardStatus.failure)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<DashboardBloc, DashboardState>(
    'DashboardNewOrderReceived bumps the snapshot counters in place',
    build: () => DashboardBloc(repo),
    seed: () => DashboardState(
      status: DashboardStatus.ready,
      snapshot: _snapshot(),
    ),
    act: (bloc) =>
        bloc.add(DashboardNewOrderReceived(MockOrdersData.orders.first)),
    expect: () => [
      isA<DashboardState>()
          .having((s) => s.snapshot?.todaysOrders, 'todaysOrders', 4)
          .having((s) => s.snapshot?.pendingOrdersCount, 'pending', 3)
          .having((s) => s.lastNewOrder, 'lastNewOrder', isNotNull),
    ],
  );

  blocTest<DashboardBloc, DashboardState>(
    'DashboardNewOrderCleared drops the transient lastNewOrder',
    build: () => DashboardBloc(repo),
    seed: () => DashboardState(
      status: DashboardStatus.ready,
      snapshot: _snapshot(),
      lastNewOrder: MockOrdersData.orders.first,
    ),
    act: (bloc) => bloc.add(const DashboardNewOrderCleared()),
    expect: () => [
      isA<DashboardState>().having((s) => s.lastNewOrder, 'lastNewOrder', isNull),
    ],
  );
}
