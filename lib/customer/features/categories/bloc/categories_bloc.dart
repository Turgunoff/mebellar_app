import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/connectivity/network_cubit.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/repositories/supabase_category_repository.dart';

sealed class CategoriesEvent extends Equatable {
  const CategoriesEvent();
  @override
  List<Object?> get props => const [];
}

class CategoriesRequested extends CategoriesEvent {
  const CategoriesRequested();
}

enum CategoriesStatus { initial, loading, ready, failure }

class CategoriesState extends Equatable {
  const CategoriesState({
    this.status = CategoriesStatus.initial,
    this.categories = const [],
    this.error,
  });

  final CategoriesStatus status;
  final List<CategoryModel> categories;
  final String? error;

  CategoriesState copyWith({
    CategoriesStatus? status,
    List<CategoryModel>? categories,
    String? error,
    bool clearError = false,
  }) {
    return CategoriesState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, categories, error];
}

class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  CategoriesBloc(this._source, {NetworkCubit? networkCubit})
    : _networkCubit = networkCubit,
      super(const CategoriesState()) {
    on<CategoriesRequested>(_onRequested);

    // Auto-retry on reconnect. Mirrors the HomeBloc pattern so the offline
    // UX is consistent across the customer shell. We only refire when the
    // previous attempt actually failed *or* we never managed to populate
    // the list — otherwise we'd hammer the API every time the user
    // toggles airplane mode.
    final cubit = _networkCubit;
    if (cubit != null) {
      _lastNetwork = cubit.state;
      _netSub = cubit.stream.listen((next) {
        final wasOffline = _lastNetwork == NetworkStatus.offline;
        _lastNetwork = next;
        if (wasOffline && next == NetworkStatus.online) {
          final needsRefresh =
              state.status == CategoriesStatus.failure ||
              state.categories.isEmpty;
          if (needsRefresh) {
            add(const CategoriesRequested());
          }
        }
      });
    }
  }

  final CategoryDataSource _source;
  final NetworkCubit? _networkCubit;
  StreamSubscription<NetworkStatus>? _netSub;
  NetworkStatus _lastNetwork = NetworkStatus.initial;

  Future<void> _onRequested(
    CategoriesRequested event,
    Emitter<CategoriesState> emit,
  ) async {
    // Cache-first paint: categories are static reference data with a 24h
    // TTL, so on a warm boot we render the grid at 0 ms and refresh
    // silently in the background. The loading spinner only shows on a true
    // cold start (no cache, never fetched).
    final cached = _source.peek();
    final hasCache = cached != null && cached.isNotEmpty;
    if (hasCache) {
      emit(
        state.copyWith(
          status: CategoriesStatus.ready,
          categories: cached,
          clearError: true,
        ),
      );
    } else {
      emit(state.copyWith(status: CategoriesStatus.loading, clearError: true));
    }

    try {
      final categories = await _source.list();
      emit(
        state.copyWith(
          status: CategoriesStatus.ready,
          categories: categories,
          clearError: true,
        ),
      );
    } catch (e) {
      // Keep the cached grid on the screen when the refresh fails; only
      // surface a hard failure when we have nothing at all to show.
      if (hasCache) {
        emit(state.copyWith(error: e.toString()));
      } else {
        emit(
          state.copyWith(status: CategoriesStatus.failure, error: e.toString()),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await _netSub?.cancel();
    return super.close();
  }
}
