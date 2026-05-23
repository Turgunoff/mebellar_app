import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/analytics.dart';
import '../../../../shared/repositories/seller_analytics_repository.dart';

/// Top-level UI status. `mutating` covers the "I'm reloading because the
/// user changed the filter" case where the previous snapshot is still
/// shown underneath so the chart doesn't blank out between fetches.
enum SellerAnalyticsStatus { initial, loading, mutating, ready, failure }

class SellerAnalyticsState extends Equatable {
  const SellerAnalyticsState({
    this.status = SellerAnalyticsStatus.initial,
    this.filter = const AnalyticsFilter(),
    this.tab = AnalyticsTab.sales,
    this.snapshot,
    this.error,
  });

  final SellerAnalyticsStatus status;
  final AnalyticsFilter filter;

  /// The active tab — pure view-model state, never sent to the repo. Tab
  /// changes do not trigger a refetch (every tab reads from the same
  /// snapshot), so swiping between them is instant.
  final AnalyticsTab tab;

  final AnalyticsSnapshot? snapshot;
  final String? error;

  /// Convenience for the screen — never `null` so the view layer can
  /// render either a real snapshot or an explicit zero-state.
  AnalyticsSnapshot get effectiveSnapshot =>
      snapshot ?? AnalyticsSnapshot.empty(filter);

  bool get isInitialLoad =>
      status == SellerAnalyticsStatus.loading && snapshot == null;

  bool get isReloading =>
      status == SellerAnalyticsStatus.mutating ||
      (status == SellerAnalyticsStatus.loading && snapshot != null);

  SellerAnalyticsState copyWith({
    SellerAnalyticsStatus? status,
    AnalyticsFilter? filter,
    AnalyticsTab? tab,
    AnalyticsSnapshot? snapshot,
    String? error,
    bool clearError = false,
    bool clearSnapshot = false,
  }) {
    return SellerAnalyticsState(
      status: status ?? this.status,
      filter: filter ?? this.filter,
      tab: tab ?? this.tab,
      snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, filter, tab, snapshot, error];
}

/// Cubit driving the analytics screen. Holds the active filter + tab,
/// the last good snapshot, and pulls fresh data from the repository on
/// mount / filter change / explicit `refresh()`. Tab switches are a pure
/// view-only operation (no refetch).
class SellerAnalyticsCubit extends Cubit<SellerAnalyticsState> {
  SellerAnalyticsCubit(this._repo) : super(const SellerAnalyticsState());

  final SellerAnalyticsRepository _repo;

  /// Loads the snapshot for the current filter. Called by the screen on
  /// first build and by pull-to-refresh.
  Future<void> load() async {
    emit(state.copyWith(
      status: SellerAnalyticsStatus.loading,
      clearError: true,
    ));
    await _fetch(state.filter);
  }

  /// Switches one of the preset ranges (7/30/90/12mo). Keeps the previous
  /// snapshot visible (with a subtle "refreshing" indicator) so the chart
  /// doesn't blink to a skeleton on every tap.
  Future<void> changeRange(AnalyticsRange range) async {
    if (range == state.filter.range &&
        range != AnalyticsRange.custom &&
        state.snapshot != null) {
      return;
    }
    final nextFilter = state.filter.copyWith(
      range: range,
      clearCustom: range != AnalyticsRange.custom,
    );
    emit(state.copyWith(
      filter: nextFilter,
      status: SellerAnalyticsStatus.mutating,
      clearError: true,
    ));
    await _fetch(nextFilter);
  }

  /// Applies a user-picked custom date window. `end` is inclusive; the
  /// filter resolves it to an exclusive next-day boundary internally.
  Future<void> applyCustomRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final nextFilter = state.filter.copyWith(
      range: AnalyticsRange.custom,
      customStart: start,
      customEnd: end,
    );
    emit(state.copyWith(
      filter: nextFilter,
      status: SellerAnalyticsStatus.mutating,
      clearError: true,
    ));
    await _fetch(nextFilter);
  }

  /// Pure view-model update — no refetch. The snapshot already carries
  /// every tab's data, so switching tabs is just a redraw.
  void changeTab(AnalyticsTab tab) {
    if (tab == state.tab) return;
    emit(state.copyWith(tab: tab));
  }

  /// Public alias used by pull-to-refresh — always refetches the
  /// current filter.
  Future<void> refresh() => _fetch(state.filter);

  Future<void> _fetch(AnalyticsFilter filter) async {
    final result = await _repo.snapshot(filter);
    // The cubit may have moved on (user tapped a new filter while the
    // previous fetch was in flight); only commit if the filter we asked
    // for still matches the active selection.
    if (filter != state.filter) return;
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
