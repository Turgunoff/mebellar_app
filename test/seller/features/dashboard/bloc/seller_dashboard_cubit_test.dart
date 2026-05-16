import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/seller/features/dashboard/bloc/seller_dashboard_cubit.dart';
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
    // The cubit subscribes to newOrders() in its constructor.
    when(() => repo.newOrders()).thenAnswer((_) => Stream<Order>.empty());
  });

  blocTest<SellerDashboardCubit, SellerDashboardState>(
    'load() emits [loading, loaded] mapping the snapshot into the view-model',
    build: () {
      when(repo.snapshot).thenAnswer((_) async => _snapshot());
      return SellerDashboardCubit(repo);
    },
    seed: () => const SellerDashboardState(
      isLoading: false,
      data: SellerDashboardData(),
    ),
    act: (cubit) => cubit.load(),
    expect: () => [
      isA<SellerDashboardState>()
          .having((s) => s.isLoading, 'isLoading', true),
      isA<SellerDashboardState>()
          .having((s) => s.isLoading, 'isLoading', false)
          .having((s) => s.data.todaysOrders, 'todaysOrders', 3)
          .having((s) => s.data.productsCount, 'productsCount', 7)
          .having((s) => s.error, 'error', isNull),
    ],
  );

  blocTest<SellerDashboardCubit, SellerDashboardState>(
    'load() surfaces a repository error and keeps the previous data',
    build: () {
      when(repo.snapshot)
          .thenAnswer((_) async => throw Exception('snapshot failed'));
      return SellerDashboardCubit(repo);
    },
    seed: () => const SellerDashboardState(
      isLoading: false,
      data: SellerDashboardData(shopName: 'Mebel Hub'),
    ),
    act: (cubit) => cubit.load(),
    expect: () => [
      isA<SellerDashboardState>()
          .having((s) => s.isLoading, 'isLoading', true),
      isA<SellerDashboardState>()
          .having((s) => s.isLoading, 'isLoading', false)
          .having((s) => s.error, 'error', isNotNull)
          .having((s) => s.data.shopName, 'previous data kept', 'Mebel Hub'),
    ],
  );

  blocTest<SellerDashboardCubit, SellerDashboardState>(
    'refresh() reloads data without flipping the loading flag',
    build: () {
      when(repo.snapshot).thenAnswer((_) async => _snapshot());
      return SellerDashboardCubit(repo);
    },
    seed: () => const SellerDashboardState(
      isLoading: false,
      data: SellerDashboardData(),
    ),
    act: (cubit) => cubit.refresh(),
    expect: () => [
      isA<SellerDashboardState>()
          .having((s) => s.isLoading, 'isLoading', false)
          .having((s) => s.data.todaysOrders, 'todaysOrders', 3),
    ],
  );
}
