import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../../shared/repositories/supabase_product_data_source.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();
  @override
  List<Object?> get props => const [];
}

class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

class SearchSubmitted extends SearchEvent {
  const SearchSubmitted(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

/// User changed the filter sheet — apply it and re-run the search. Goes
/// through the same debounce as text input so a rapid sequence of toggles
/// (common when wiping out a panel of filters) only fires one request.
class SearchFilterChanged extends SearchEvent {
  const SearchFilterChanged(this.filter);
  final ProductSearchFilter filter;
  @override
  List<Object?> get props => [filter];
}

class SearchHistoryCleared extends SearchEvent {
  const SearchHistoryCleared();
}

enum SearchStatus { idle, loading, ready, failure }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.filter = const ProductSearchFilter(),
    this.results = const [],
    this.recent = const [],
    this.error,
  });

  final SearchStatus status;
  final String query;
  final ProductSearchFilter filter;
  final List<SupabaseProductModel> results;
  final List<String> recent;
  final String? error;

  /// True when the user has either typed something or expressed any filter
  /// intent (a facet OR a non-default sort). Drives the screen's choice
  /// between the "browse" idle state and the results grid.
  bool get hasInput => query.isNotEmpty || !filter.isDefault;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    ProductSearchFilter? filter,
    List<SupabaseProductModel>? results,
    List<String>? recent,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      results: results ?? this.results,
      recent: recent ?? this.recent,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, query, filter, results, recent, error];
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    required SupabaseProductDataSource source,
    required Box cacheBox,
    AnalyticsService? analytics,
  })  : _source = source,
        _cache = cacheBox,
        _analytics = analytics,
        super(SearchState(recent: _readRecent(cacheBox))) {
    on<SearchQueryChanged>(_onQueryChanged, transformer: _debounce());
    on<SearchFilterChanged>(_onFilterChanged, transformer: _debounce());
    on<SearchSubmitted>(_onSubmitted);
    on<SearchHistoryCleared>(_onHistoryCleared);
  }

  final AnalyticsService? _analytics;

  static const _recentKey = 'search_recent';
  static const _maxRecent = 10;
  static const _debounceDuration = Duration(milliseconds: 300);

  final SupabaseProductDataSource _source;
  final Box _cache;

  static List<String> _readRecent(Box box) {
    final raw = box.get(_recentKey);
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  /// ROADMAP B.7 — debounce + `restartable`. The debounce drops keystrokes
  /// (and rapid filter toggles) that arrive within `_debounceDuration` of
  /// each other so we don't fire a Supabase request per change; `restartable`
  /// cancels any still-in-flight search when a newer one settles, so a slow
  /// request can't land stale results over fresher input.
  EventTransformer<E> _debounce<E>() {
    return (events, mapper) {
      final debounced =
          events.transform(_DebounceTransformer<E>(_debounceDuration));
      return restartable<E>()(debounced, mapper);
    };
  }

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    await _runSearch(event.query.trim(), state.filter, emit);
  }

  Future<void> _onFilterChanged(
    SearchFilterChanged event,
    Emitter<SearchState> emit,
  ) async {
    await _runSearch(state.query, event.filter, emit);
  }

  Future<void> _runSearch(
    String query,
    ProductSearchFilter filter,
    Emitter<SearchState> emit,
  ) async {
    // No query and a default (untouched) filter => nothing to search; reset
    // to idle so the screen shows the "browse" placeholder rather than a
    // stale results list. A non-default sort alone is intent enough to
    // proceed — the data source orders the whole catalogue accordingly.
    if (query.isEmpty && filter.isDefault) {
      emit(
        state.copyWith(
          status: SearchStatus.idle,
          query: query,
          filter: filter,
          results: const [],
          clearError: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: SearchStatus.loading,
        query: query,
        filter: filter,
        clearError: true,
      ),
    );
    try {
      final results = await _source.search(query, filter: filter);
      // A newer keystroke or filter toggle may have superseded this request —
      // drop the result if so to avoid a flicker of stale data.
      if (state.query != query || state.filter != filter) return;
      emit(state.copyWith(status: SearchStatus.ready, results: results));

      // Fire analytics on the *successful, settled* search — we never
      // double-count when the user mid-types another character, because
      // restartable() cancels the older event handler before this point.
      if (query.isNotEmpty) {
        unawaited(_analytics?.searchPerformed(
          query: query,
          resultsCount: results.length,
          appliedFiltersCount: filter.activeCount,
        ));
      } else if (filter.isNotEmpty || !filter.isDefault) {
        unawaited(_analytics?.filterApplied(
          activeFacetCount: filter.activeCount,
          sort: filter.sort.name,
        ));
      }
    } catch (e) {
      if (state.query != query || state.filter != filter) return;
      emit(state.copyWith(status: SearchStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onSubmitted(
    SearchSubmitted event,
    Emitter<SearchState> emit,
  ) async {
    final q = event.query.trim();
    if (q.isEmpty) return;
    final updated = [
      q,
      ...state.recent.where((s) => s != q),
    ].take(_maxRecent).toList();
    await _cache.put(_recentKey, updated);
    emit(state.copyWith(recent: updated));
  }

  Future<void> _onHistoryCleared(
    SearchHistoryCleared event,
    Emitter<SearchState> emit,
  ) async {
    await _cache.delete(_recentKey);
    emit(state.copyWith(recent: const []));
  }
}

class _DebounceTransformer<T> extends StreamTransformerBase<T, T> {
  _DebounceTransformer(this.duration);

  final Duration duration;

  @override
  Stream<T> bind(Stream<T> stream) {
    Timer? timer;
    late StreamController<T> controller;
    StreamSubscription<T>? sub;

    void onListen() {
      sub = stream.listen(
        (event) {
          timer?.cancel();
          timer = Timer(duration, () => controller.add(event));
        },
        onError: controller.addError,
        onDone: () {
          timer?.cancel();
          controller.close();
        },
      );
    }

    Future<void> onCancel() async {
      timer?.cancel();
      await sub?.cancel();
    }

    controller = StreamController<T>(onListen: onListen, onCancel: onCancel);
    return controller.stream;
  }
}
