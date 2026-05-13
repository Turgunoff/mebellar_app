import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/tariff.dart';
import '../../../../shared/repositories/tariff_repository.dart';

sealed class TariffEvent extends Equatable {
  const TariffEvent();
  @override
  List<Object?> get props => const [];
}

class TariffRequested extends TariffEvent {
  const TariffRequested();
}

class TariffPeriodChanged extends TariffEvent {
  const TariffPeriodChanged(this.period);
  final BillingPeriod period;
  @override
  List<Object?> get props => [period];
}

class _TariffPendingChanged extends TariffEvent {
  const _TariffPendingChanged(this.pending);
  final TariffSubscription? pending;
  @override
  List<Object?> get props => [pending?.id, pending?.status];
}

class _TariffPlanChanged extends TariffEvent {
  const _TariffPlanChanged(this.plan);
  final TariffPlan plan;
  @override
  List<Object?> get props => [plan];
}

enum TariffStatus { initial, loading, ready, failure }

class TariffState extends Equatable {
  const TariffState({
    this.status = TariffStatus.initial,
    this.snapshot,
    this.pending,
    this.history = const [],
    this.plans = const [],
    this.period = BillingPeriod.monthly,
    this.error,
  });

  final TariffStatus status;
  final TariffSnapshot? snapshot;
  final TariffSubscription? pending;
  final List<TariffSubscription> history;

  /// Server-driven plan catalog. Iterated by the tariff screen so prices,
  /// limits, features and the recommended ribbon all come from Supabase.
  final List<SubscriptionPlan> plans;

  final BillingPeriod period;
  final String? error;

  TariffPlan get currentPlan => snapshot?.plan ?? TariffPlan.free;
  bool get hasPending => pending != null && pending!.status.isPending;

  TariffState copyWith({
    TariffStatus? status,
    TariffSnapshot? snapshot,
    TariffSubscription? pending,
    bool clearPending = false,
    List<TariffSubscription>? history,
    List<SubscriptionPlan>? plans,
    BillingPeriod? period,
    String? error,
    bool clearError = false,
  }) {
    return TariffState(
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      pending: clearPending ? null : (pending ?? this.pending),
      history: history ?? this.history,
      plans: plans ?? this.plans,
      period: period ?? this.period,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        snapshot,
        pending,
        history.length,
        plans,
        period,
        error,
      ];
}

class TariffBloc extends Bloc<TariffEvent, TariffState> {
  TariffBloc(this._repo) : super(const TariffState()) {
    on<TariffRequested>(_onRequested);
    on<TariffPeriodChanged>(
        (event, emit) => emit(state.copyWith(period: event.period)));
    on<_TariffPendingChanged>((event, emit) => emit(state.copyWith(
          pending: event.pending,
          clearPending: event.pending == null,
        )));
    on<_TariffPlanChanged>((event, emit) {
      final snap = state.snapshot;
      emit(state.copyWith(
        snapshot: snap == null
            ? TariffSnapshot(plan: event.plan, activeProductsCount: 0)
            : TariffSnapshot(
                plan: event.plan,
                activeProductsCount: snap.activeProductsCount,
              ),
      ));
    });

    _pendingSub =
        _repo.watchPending().listen((p) => add(_TariffPendingChanged(p)));
    _planSub =
        _repo.watchCurrentPlan().listen((p) => add(_TariffPlanChanged(p)));
  }

  final TariffRepository _repo;
  StreamSubscription<TariffSubscription?>? _pendingSub;
  StreamSubscription<TariffPlan>? _planSub;

  Future<void> _onRequested(
    TariffRequested event,
    Emitter<TariffState> emit,
  ) async {
    emit(state.copyWith(status: TariffStatus.loading, clearError: true));
    try {
      // Run the four reads in parallel — they're independent and we want a
      // single emit when everything is in (avoids flicker between cached
      // snapshot and freshly-fetched plans).
      final results = await Future.wait<dynamic>([
        _repo.currentSnapshot(),
        _repo.currentPending(),
        _repo.history(),
        _repo.fetchPlans(),
      ]);
      final snapshot = results[0] as TariffSnapshot;
      final pending = results[1] as TariffSubscription?;
      final history = results[2] as List<TariffSubscription>;
      final plans = results[3] as List<SubscriptionPlan>;

      emit(state.copyWith(
        status: TariffStatus.ready,
        snapshot: snapshot,
        pending: pending,
        clearPending: pending == null,
        history: history,
        plans: plans,
      ));
    } catch (e) {
      emit(state.copyWith(status: TariffStatus.failure, error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _pendingSub?.cancel();
    await _planSub?.cancel();
    return super.close();
  }
}
