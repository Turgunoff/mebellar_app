import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/error/failure.dart';
import 'package:woody_app/seller/features/analytics/bloc/seller_analytics_cubit.dart';
import 'package:woody_app/shared/models/analytics.dart';

import '../fake_seller_analytics_repository.dart';

void main() {
  AnalyticsSnapshot snapshotWith({
    required AnalyticsRange range,
    num revenue = 100,
    num previous = 0,
    int orders = 3,
    int units = 7,
  }) {
    return AnalyticsSnapshot(
      filter: AnalyticsFilter(range: range),
      totalRevenue: revenue,
      previousRevenue: previous,
      ordersCount: orders,
      unitsSold: units,
      avgOrderValue: orders == 0 ? 0 : revenue / orders,
      series: const [],
      topProducts: const [],
      categoryBreakdown: const [],
      orders: OrdersBreakdown.empty(),
      reviews: ReviewsBreakdown.empty(),
      customers: CustomersBreakdown.empty(),
    );
  }

  group('SellerAnalyticsCubit', () {
    late FakeSellerAnalyticsRepository repo;

    setUp(() => repo = FakeSellerAnalyticsRepository());

    blocTest<SellerAnalyticsCubit, SellerAnalyticsState>(
      'load: loading → ready with the snapshot for the default 30d range',
      build: () {
        repo.setSnapshot(
          AnalyticsRange.d30,
          snapshotWith(range: AnalyticsRange.d30, revenue: 50_000_000),
        );
        return SellerAnalyticsCubit(repo);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        // Loading frame
        isA<SellerAnalyticsState>()
            .having((s) => s.status, 'status', SellerAnalyticsStatus.loading),
        // Ready with snapshot
        isA<SellerAnalyticsState>()
            .having((s) => s.status, 'status', SellerAnalyticsStatus.ready)
            .having(
              (s) => s.snapshot?.totalRevenue,
              'revenue',
              50_000_000,
            ),
      ],
    );

    blocTest<SellerAnalyticsCubit, SellerAnalyticsState>(
      'load: failure surfaces error message and keeps no snapshot',
      build: () {
        repo.failNextWith(const ServerFailure(message: 'boom'));
        return SellerAnalyticsCubit(repo);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<SellerAnalyticsState>()
            .having((s) => s.status, 'status', SellerAnalyticsStatus.loading),
        isA<SellerAnalyticsState>()
            .having((s) => s.status, 'status', SellerAnalyticsStatus.failure)
            .having((s) => s.error, 'error', 'boom')
            .having((s) => s.snapshot, 'snapshot stays null', isNull),
      ],
    );

    blocTest<SellerAnalyticsCubit, SellerAnalyticsState>(
      'changeRange: emits mutating then ready, swaps in the new snapshot',
      build: () {
        repo.setSnapshot(
          AnalyticsRange.d30,
          snapshotWith(range: AnalyticsRange.d30, revenue: 100),
        );
        repo.setSnapshot(
          AnalyticsRange.d7,
          snapshotWith(range: AnalyticsRange.d7, revenue: 25),
        );
        return SellerAnalyticsCubit(repo);
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.changeRange(AnalyticsRange.d7);
      },
      verify: (cubit) {
        expect(cubit.state.filter.range, AnalyticsRange.d7);
        expect(cubit.state.status, SellerAnalyticsStatus.ready);
        expect(cubit.state.snapshot?.totalRevenue, 25);
      },
    );

    blocTest<SellerAnalyticsCubit, SellerAnalyticsState>(
      'changeRange to the same range is a no-op when a snapshot is loaded',
      build: () {
        repo.setSnapshot(
          AnalyticsRange.d30,
          snapshotWith(range: AnalyticsRange.d30),
        );
        return SellerAnalyticsCubit(repo);
      },
      act: (cubit) async {
        await cubit.load();
        final beforeCalls = repo.snapshotCalls;
        await cubit.changeRange(AnalyticsRange.d30);
        expect(repo.snapshotCalls, beforeCalls,
            reason: 'repository must not be re-hit for the same range');
      },
      verify: (cubit) =>
          expect(cubit.state.status, SellerAnalyticsStatus.ready),
    );

    blocTest<SellerAnalyticsCubit, SellerAnalyticsState>(
      'refresh: re-fetches the current range and replaces the snapshot',
      build: () {
        repo.setSnapshot(
          AnalyticsRange.d30,
          snapshotWith(range: AnalyticsRange.d30, revenue: 10),
        );
        return SellerAnalyticsCubit(repo);
      },
      act: (cubit) async {
        await cubit.load();
        repo.setSnapshot(
          AnalyticsRange.d30,
          snapshotWith(range: AnalyticsRange.d30, revenue: 999),
        );
        await cubit.refresh();
      },
      verify: (cubit) {
        expect(cubit.state.snapshot?.totalRevenue, 999);
        expect(repo.snapshotCalls, 2);
      },
    );

    blocTest<SellerAnalyticsCubit, SellerAnalyticsState>(
      'changeRange while a previous fetch is in flight: late response is '
      'dropped, the latest range wins',
      build: () {
        repo.setSnapshot(
          AnalyticsRange.d30,
          snapshotWith(range: AnalyticsRange.d30, revenue: 10),
        );
        repo.setSnapshot(
          AnalyticsRange.d7,
          snapshotWith(range: AnalyticsRange.d7, revenue: 99),
        );
        return SellerAnalyticsCubit(repo);
      },
      act: (cubit) async {
        // Trigger the initial load; while it's "in flight" we mutate the
        // range, so by the time the d30 response would land the cubit
        // has moved on to d7. The repository fake completes synchronously
        // here — exercising the same conditional commit guard.
        final loadFuture = cubit.load();
        await cubit.changeRange(AnalyticsRange.d7);
        await loadFuture;
      },
      verify: (cubit) {
        expect(cubit.state.filter.range, AnalyticsRange.d7);
        // d7 is the active range, so its snapshot must be the visible one
        // regardless of the order in which the futures settled.
        expect(cubit.state.snapshot?.totalRevenue, 99);
      },
    );

    blocTest<SellerAnalyticsCubit, SellerAnalyticsState>(
      'changeTab is a pure view-only update — no repository call',
      build: () {
        repo.setSnapshot(
          AnalyticsRange.d30,
          snapshotWith(range: AnalyticsRange.d30),
        );
        return SellerAnalyticsCubit(repo);
      },
      act: (cubit) async {
        await cubit.load();
        final before = repo.snapshotCalls;
        cubit.changeTab(AnalyticsTab.reviews);
        expect(repo.snapshotCalls, before);
      },
      verify: (cubit) => expect(cubit.state.tab, AnalyticsTab.reviews),
    );

    blocTest<SellerAnalyticsCubit, SellerAnalyticsState>(
      'applyCustomRange: swaps the filter and refetches',
      build: () => SellerAnalyticsCubit(repo),
      act: (cubit) async {
        await cubit.load();
        await cubit.applyCustomRange(
          start: DateTime(2026, 4, 1),
          end: DateTime(2026, 4, 30),
        );
      },
      verify: (cubit) {
        expect(cubit.state.filter.range, AnalyticsRange.custom);
        expect(cubit.state.filter.customStart, DateTime(2026, 4, 1));
        expect(cubit.state.filter.customEnd, DateTime(2026, 4, 30));
      },
    );

    blocTest<SellerAnalyticsCubit, SellerAnalyticsState>(
      'effectiveSnapshot always returns a usable value (zero state by default)',
      build: () => SellerAnalyticsCubit(repo),
      verify: (cubit) {
        final snap = cubit.state.effectiveSnapshot;
        expect(snap.totalRevenue, 0);
        expect(snap.isEmpty, isTrue);
      },
    );
  });

  group('AnalyticsFilter windows', () {
    final now = DateTime.utc(2026, 5, 20, 14, 35);

    test('d7 windowFor spans 7 days ending at the next UTC midnight', () {
      const filter = AnalyticsFilter(range: AnalyticsRange.d7);
      final w = filter.windowFor(now);
      expect(w.endExclusive, DateTime.utc(2026, 5, 21));
      expect(w.start, DateTime.utc(2026, 5, 14));
      expect(w.contains(DateTime.utc(2026, 5, 15, 10)), isTrue);
      expect(w.contains(DateTime.utc(2026, 5, 14)), isTrue);
      expect(
        w.contains(DateTime.utc(2026, 5, 21)),
        isFalse,
        reason: 'endExclusive is excluded',
      );
    });

    test('previousWindowFor is the immediately preceding span', () {
      const filter = AnalyticsFilter(range: AnalyticsRange.d30);
      final cur = filter.windowFor(now);
      final prev = filter.previousWindowFor(now);
      expect(prev.endExclusive, cur.start);
      expect(prev.start, cur.start.subtract(const Duration(days: 30)));
    });

    test('m12 is monthly and 365 days wide', () {
      const r = AnalyticsRange.m12;
      expect(r.isMonthly, isTrue);
      expect(r.buckets, 12);
      expect(r.days, 365);
    });

    test('custom range respects user-picked bounds', () {
      final filter = AnalyticsFilter(
        range: AnalyticsRange.custom,
        customStart: DateTime(2026, 4, 1),
        customEnd: DateTime(2026, 4, 30),
      );
      final w = filter.windowFor(now);
      expect(w.start, DateTime.utc(2026, 4, 1));
      expect(w.endExclusive, DateTime.utc(2026, 5, 1));
    });
  });

  group('AnalyticsSnapshot', () {
    test('deltaPercent is null when previous revenue is zero', () {
      final s = AnalyticsSnapshot(
        filter: const AnalyticsFilter(range: AnalyticsRange.d7),
        totalRevenue: 100,
        previousRevenue: 0,
        ordersCount: 1,
        unitsSold: 1,
        avgOrderValue: 100,
        series: const [],
        topProducts: const [],
        categoryBreakdown: const [],
        orders: OrdersBreakdown.empty(),
        reviews: ReviewsBreakdown.empty(),
        customers: CustomersBreakdown.empty(),
      );
      expect(s.deltaPercent, isNull);
    });

    test('deltaPercent computes the relative change', () {
      final s = AnalyticsSnapshot(
        filter: const AnalyticsFilter(range: AnalyticsRange.d7),
        totalRevenue: 120,
        previousRevenue: 100,
        ordersCount: 1,
        unitsSold: 1,
        avgOrderValue: 120,
        series: const [],
        topProducts: const [],
        categoryBreakdown: const [],
        orders: OrdersBreakdown.empty(),
        reviews: ReviewsBreakdown.empty(),
        customers: CustomersBreakdown.empty(),
      );
      expect(s.deltaPercent, 20);
    });

    test('isEmpty is true for the explicit empty factory', () {
      expect(
        AnalyticsSnapshot.empty(
          const AnalyticsFilter(range: AnalyticsRange.d30),
        ).isEmpty,
        isTrue,
      );
    });
  });
}
