import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/product.dart';
import '../../../../shared/repositories/favorites_repository.dart';

sealed class FavoritesEvent extends Equatable {
  const FavoritesEvent();
  @override
  List<Object?> get props => const [];
}

class FavoritesRequested extends FavoritesEvent {
  const FavoritesRequested();
}

class FavoriteToggled extends FavoritesEvent {
  const FavoriteToggled(this.product);
  final Product product;
  @override
  List<Object?> get props => [product.id];
}

class FavoriteRemoved extends FavoritesEvent {
  const FavoriteRemoved(this.productId);
  final String productId;
  @override
  List<Object?> get props => [productId];
}

class _FavoritesIdsChanged extends FavoritesEvent {
  const _FavoritesIdsChanged(this.ids);
  final Set<String> ids;
  @override
  List<Object?> get props => [ids];
}

enum FavoritesStatus { initial, loading, ready, failure }

class FavoritesState extends Equatable {
  const FavoritesState({
    this.status = FavoritesStatus.initial,
    this.products = const [],
    this.ids = const <String>{},
    this.error,
  });

  final FavoritesStatus status;
  final List<Product> products;
  final Set<String> ids;
  final String? error;

  bool isFavorite(String productId) => ids.contains(productId);

  FavoritesState copyWith({
    FavoritesStatus? status,
    List<Product>? products,
    Set<String>? ids,
    String? error,
    bool clearError = false,
  }) {
    return FavoritesState(
      status: status ?? this.status,
      products: products ?? this.products,
      ids: ids ?? this.ids,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, products, ids, error];
}

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  FavoritesBloc(this._repo) : super(const FavoritesState()) {
    on<FavoritesRequested>(_onRequested);
    on<FavoriteToggled>(_onToggled);
    on<FavoriteRemoved>(_onRemoved);
    on<_FavoritesIdsChanged>(_onIdsChanged);

    _sub = _repo.watchIds().listen((ids) => add(_FavoritesIdsChanged(ids)));
  }

  final FavoritesRepository _repo;
  StreamSubscription<Set<String>>? _sub;

  Future<void> _onRequested(
    FavoritesRequested event,
    Emitter<FavoritesState> emit,
  ) async {
    emit(state.copyWith(status: FavoritesStatus.loading, clearError: true));
    try {
      final list = await _repo.list();
      emit(state.copyWith(
        status: FavoritesStatus.ready,
        products: list,
        ids: list.map((p) => p.id).toSet(),
      ));
    } catch (e) {
      emit(state.copyWith(status: FavoritesStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onToggled(
    FavoriteToggled event,
    Emitter<FavoritesState> emit,
  ) async {
    final wasFav = state.ids.contains(event.product.id);
    final nextIds = Set<String>.from(state.ids);
    if (wasFav) {
      nextIds.remove(event.product.id);
    } else {
      nextIds.add(event.product.id);
    }
    emit(state.copyWith(ids: nextIds));
    try {
      await _repo.toggle(event.product);
      // Re-fetch list so the favorites screen stays in sync after a toggle.
      if (state.status == FavoritesStatus.ready) {
        final list = await _repo.list();
        emit(state.copyWith(
          products: list,
          ids: list.map((p) => p.id).toSet(),
        ));
      }
    } catch (e) {
      // Roll back the optimistic toggle on failure.
      emit(state.copyWith(ids: state.ids, error: e.toString()));
    }
  }

  Future<void> _onRemoved(
    FavoriteRemoved event,
    Emitter<FavoritesState> emit,
  ) async {
    final previousProducts = state.products;
    final previousIds = state.ids;
    emit(state.copyWith(
      products: previousProducts
          .where((p) => p.id != event.productId)
          .toList(),
      ids: Set<String>.from(previousIds)..remove(event.productId),
    ));
    try {
      await _repo.remove(event.productId);
    } catch (e) {
      emit(state.copyWith(
        products: previousProducts,
        ids: previousIds,
        error: e.toString(),
      ));
    }
  }

  void _onIdsChanged(
    _FavoritesIdsChanged event,
    Emitter<FavoritesState> emit,
  ) {
    emit(state.copyWith(ids: event.ids));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
