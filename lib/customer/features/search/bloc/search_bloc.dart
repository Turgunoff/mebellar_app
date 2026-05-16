import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

class SearchHistoryCleared extends SearchEvent {
  const SearchHistoryCleared();
}

enum SearchStatus { idle, loading, ready, failure }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.results = const [],
    this.recent = const [],
    this.error,
  });

  final SearchStatus status;
  final String query;
  final List<SupabaseProductModel> results;
  final List<String> recent;
  final String? error;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<SupabaseProductModel>? results,
    List<String>? recent,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      recent: recent ?? this.recent,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, query, results, recent, error];
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    required SupabaseProductDataSource source,
    required Box cacheBox,
  }) : _source = source,
       _cache = cacheBox,
       super(SearchState(recent: _readRecent(cacheBox))) {
    on<SearchQueryChanged>(_onQueryChanged, transformer: _debounce());
    on<SearchSubmitted>(_onSubmitted);
    on<SearchHistoryCleared>(_onHistoryCleared);
  }

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
  /// that arrive within `_debounceDuration` of each other so we don't fire a
  /// Supabase request per keystroke; `restartable` then cancels any still
  /// in-flight search when a newer query settles, so a slow request can't
  /// land stale results over a fresher query.
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
    final q = event.query.trim();
    if (q.isEmpty) {
      emit(
        state.copyWith(
          status: SearchStatus.idle,
          query: '',
          results: const [],
          clearError: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: SearchStatus.loading,
        query: q,
        clearError: true,
      ),
    );
    try {
      final results = await _source.search(q);
      // A faster keystroke may have superseded this query — drop the result
      // if so to avoid a flicker of stale data.
      if (state.query != q) return;
      emit(state.copyWith(status: SearchStatus.ready, results: results));
    } catch (e) {
      if (state.query != q) return;
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
