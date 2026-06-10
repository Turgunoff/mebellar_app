import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/error/failure.dart';
import 'package:woody_app/core/result/result.dart';
import 'package:woody_app/seller/features/tariff/bloc/tariff_bloc.dart';
import 'package:woody_app/seller/features/tariff/bloc/tariff_upgrade_bloc.dart';
import '../../../../fixtures/mocks/mock/mock_tariff_repository.dart';
import 'package:woody_app/shared/models/tariff.dart';

/// Pending/history 500 while snapshot + plans succeed — the catalogue must
/// still render (these reads only power the banner and the history sheet).
class _FlakySecondaryTariffRepository extends MockTariffRepository {
  @override
  Future<Result<TariffSubscription?>> currentPending() async =>
      const Err(UnknownFailure(message: 'pending 500'));

  @override
  Future<Result<List<TariffSubscription>>> history() async =>
      const Err(UnknownFailure(message: 'history 500'));
}

/// The plan catalogue itself 500s — that IS a core failure and must surface.
class _BrokenPlansTariffRepository extends MockTariffRepository {
  @override
  Future<Result<List<SubscriptionPlan>>> fetchPlans() async =>
      const Err(ServerFailure(message: 'plans 500'));
}

void main() {
  group('TariffBloc (mock repository)', () {
    blocTest<TariffBloc, TariffState>(
      'fetch -> snapshot + history seed loaded',
      build: () => TariffBloc(MockTariffRepository()),
      act: (bloc) => bloc.add(const TariffRequested()),
      // 3 sequential repo calls × 280ms each ≈ 840ms; budget 1.2s.
      wait: const Duration(milliseconds: 1200),
      verify: (bloc) {
        expect(bloc.state.status, TariffStatus.ready);
        expect(bloc.state.currentPlan, TariffPlan.free);
        expect(bloc.state.history.length, greaterThanOrEqualTo(1));
        expect(bloc.state.hasPending, isFalse);
      },
    );

    blocTest<TariffBloc, TariffState>(
      'secondary read failures (pending/history) still surface the catalogue',
      build: () => TariffBloc(_FlakySecondaryTariffRepository()),
      act: (bloc) => bloc.add(const TariffRequested()),
      wait: const Duration(milliseconds: 1200),
      verify: (bloc) {
        expect(bloc.state.status, TariffStatus.ready);
        expect(bloc.state.plans, isNotEmpty);
        expect(bloc.state.history, isEmpty);
        expect(bloc.state.hasPending, isFalse);
      },
    );

    blocTest<TariffBloc, TariffState>(
      'plan catalogue failure surfaces as failure with the error message',
      build: () => TariffBloc(_BrokenPlansTariffRepository()),
      act: (bloc) => bloc.add(const TariffRequested()),
      wait: const Duration(milliseconds: 1200),
      verify: (bloc) {
        expect(bloc.state.status, TariffStatus.failure);
        expect(bloc.state.plans, isEmpty);
        expect(bloc.state.error, 'plans 500');
      },
    );

    blocTest<TariffBloc, TariffState>(
      'period toggle switches monthly <-> yearly',
      build: () => TariffBloc(MockTariffRepository()),
      act: (bloc) async {
        bloc.add(const TariffRequested());
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        bloc.add(const TariffPeriodChanged(BillingPeriod.yearly));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.period, BillingPeriod.yearly);
      },
    );
  });

  group('TariffUpgradeBloc (mock repository)', () {
    blocTest<TariffUpgradeBloc, TariffUpgradeState>(
      'started -> plan + period saved, status idle',
      build: () => TariffUpgradeBloc(MockTariffRepository()),
      act: (bloc) => bloc.add(
        const TariffUpgradeStarted(
          plan: TariffPlan.pro,
          period: BillingPeriod.yearly,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.plan, TariffPlan.pro);
        expect(bloc.state.period, BillingPeriod.yearly);
        expect(bloc.state.amount, TariffPlan.pro.yearlyPriceUzs);
        expect(bloc.state.status, TariffUpgradeFlowStatus.idle);
      },
    );

    blocTest<TariffUpgradeBloc, TariffUpgradeState>(
      'screenshot upload -> ready, then submit -> submitted with subscription',
      build: () => TariffUpgradeBloc(MockTariffRepository()),
      act: (bloc) async {
        bloc.add(
          const TariffUpgradeStarted(
            plan: TariffPlan.pro,
            period: BillingPeriod.monthly,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        // The mock repo only stashes the path — file existence is irrelevant.
        bloc.add(
          TariffUpgradeScreenshotPicked(
            file: File('./test/.fake/payment.jpg'),
            fileExtension: 'jpg',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 900));
        bloc.add(const TariffUpgradeSubmitted());
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      verify: (bloc) {
        expect(bloc.state.status, TariffUpgradeFlowStatus.submitted);
        expect(bloc.state.subscription, isNotNull);
        expect(bloc.state.subscription!.status, TariffUpgradeStatus.pending);
      },
    );
  });

  group('TariffPlan price helpers', () {
    test('yearly price applies a discount over 12 monthly payments', () {
      // Sanity check the catalog math so the UI doesn't accidentally show
      // a yearly plan that costs *more* than 12 months. Only paid plans —
      // free and the backend-granted trial bonus have no price at all.
      for (final plan in TariffPlan.values.where(
        (p) => p.monthlyPriceUzs > 0,
      )) {
        expect(
          plan.yearlyPriceUzs,
          lessThan(plan.monthlyPriceUzs * 12),
          reason: '${plan.code} yearly should be cheaper than 12× monthly',
        );
      }
    });

    test('Pro is the recommended plan', () {
      final recommended = TariffPlan.values
          .where((p) => p.recommended)
          .toList();
      expect(recommended, [TariffPlan.pro]);
    });
  });

  group('TariffSubscription SLA countdown', () {
    test('pending request returns positive remaining within 24 hours', () {
      final sub = TariffSubscription(
        id: 's',
        plan: TariffPlan.pro,
        period: BillingPeriod.monthly,
        amount: 299_000,
        status: TariffUpgradeStatus.pending,
        submittedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(sub.slaRemaining.inHours, greaterThanOrEqualTo(21));
      expect(sub.slaRemaining.inHours, lessThanOrEqualTo(22));
    });

    test('approved request reports zero remaining', () {
      final sub = TariffSubscription(
        id: 's',
        plan: TariffPlan.pro,
        period: BillingPeriod.monthly,
        amount: 299_000,
        status: TariffUpgradeStatus.approved,
        submittedAt: DateTime.now(),
      );
      expect(sub.slaRemaining, Duration.zero);
    });
  });
}
