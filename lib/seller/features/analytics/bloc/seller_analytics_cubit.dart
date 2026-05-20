import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/analytics.dart';
import '../../../../shared/repositories/seller_analytics_repository.dart';

/// Top-level UI status. `mutating` covers the "I'm reloading because the
/// user changed the range" case where the previous snapshot is still
/// shown underneath so the chart doesn't blank out between fetches.
enum SellerAnalyticsStatus { initial, loading, mutating, ready, failure }

class SellerAnalyticsState extends Equatable {
  const SellerAnalyticsState({
    this.status = SellerAnalyticsStatus.initial,
    this.range = AnalyticsRange.d30,
    this.snapshot,
    this.error,
  });

  final SellerAnalyticsStatus status;
  final AnalyticsRange range;
  final AnalyticsSnapshot? snapshot;
  final String? error;

  /// Convenience for the screen — never `null` so the view layer can
  /// render either a real snapshot or an explicit zero-state.
  AnalyticsSnapshot get effectiveSnapshot =>
      snapshot ?? AnalyticsSnapshot.empty(range);

  bool get isInitialLoad =>
      status == SellerAnalyticsStatus.loading && snapshot == null;

  bool get isReloading =>
      status == SellerAnalyticsStatus.mutating ||
      (status == SellerAnalyticsStatus.loading && snapshot != null);

  SellerAnalyticsState copyWith({
    SellerAnalyticsStatus? status,
    AnalyticsRange? range,
    AnalyticsSnapshot? snapshot,
    String? error,
    bool clearError = false,
    bool clearSnapshot = false,
  }) {
    return SellerAnalyticsState(
      status: status ?? this.status,
      range: range ?? this.range,
      snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, range, snapshot, error];
}

/// Cubit driving the analytics screen. Holds the current range, the
/// last good snapshot, and pulls fresh data from the repository on
/// mount / range change / explicit `refresh()`.
class SellerAnalyticsCubit extends Cubit<SellerAnalyticsState> {
  SellerAnalyticsCubit(this._repo) : super(const SellerAnalyticsState());

  final SellerAnalyticsRepository _repo;

  /// Loads the snapshot for the current range. Called by the screen on
  /// first build and by pull-to-refresh.
  Future<void> load() async {
    emit(state.copyWith(
      status: SellerAnalyticsStatus.loading,
      clearError: true,
    ));
    await _fetch(state.range);
  }

  /// Switches the range and refetches. Keeps the previous snapshot
  /// visible (with a subtle "refreshing" indicator) so the chart doesn't
  /// blink to a skeleton on every tab tap.
  Future<void> changeRange(AnalyticsRange range) async {
    if (range == state.range && state.snapshot != null) return;
    emit(state.copyWith(
      range: range,
      status: SellerAnalyticsStatus.mutating,
      clearError: true,
    ));
    await _fetch(range);
  }

  /// Public alias used by pull-to-refresh — always refetches the
  /// current range.
  Future<void> refresh() => _fetch(state.range);

  Future<void> _fetch(AnalyticsRange range) async {
    final result = await _repo.snapshot(range);
    // The cubit may have moved on (user tapped a new range while the
    // previous fetch was in flight); only commit if the range we asked
    // for still matches the active selection.
    if (range != state.range) return;
    result.fold(
      ok: (snapshot) => emit(state.copyWith(
        status: SellerAnalyticsStatus.ready,
        snapshot: snapshot,
        clearError: true,
      )),
      err: (failure) => emit(state.copyWith(
        status: SellerAnalyticsStatus.failure,
        error: failure.message,
      )),
    );
  }
}
