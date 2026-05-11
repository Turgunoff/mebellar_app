import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/seller_product.dart';
import '../../../../shared/repositories/seller_product_repository.dart';

sealed class SellerProductsEvent extends Equatable {
  const SellerProductsEvent();
  @override
  List<Object?> get props => const [];
}

class SellerProductsRequested extends SellerProductsEvent {
  const SellerProductsRequested();
}

class SellerProductsFilterChanged extends SellerProductsEvent {
  const SellerProductsFilterChanged(this.filter);
  final SellerProductFilter filter;
  @override
  List<Object?> get props => [filter];
}

class SellerProductsSearchChanged extends SellerProductsEvent {
  const SellerProductsSearchChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

class SellerProductArchived extends SellerProductsEvent {
  const SellerProductArchived(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class SellerProductSubmitted extends SellerProductsEvent {
  const SellerProductSubmitted(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class _SellerProductsRefreshed extends SellerProductsEvent {
  const _SellerProductsRefreshed(this.products);
  final List<SellerProduct> products;
  @override
  List<Object?> get props => [products];
}

enum SellerProductsStatus { initial, loading, ready, mutating, failure }

class SellerProductsState extends Equatable {
  const SellerProductsState({
    this.status = SellerProductsStatus.initial,
    this.products = const [],
    this.filter = const SellerProductFilter(),
    this.error,
  });

  final SellerProductsStatus status;
  final List<SellerProduct> products;
  final SellerProductFilter filter;
  final String? error;

  List<SellerProduct> get visibleProducts =>
      products.where(filter.matches).toList();

  SellerProductsState copyWith({
    SellerProductsStatus? status,
    List<SellerProduct>? products,
    SellerProductFilter? filter,
    String? error,
    bool clearError = false,
  }) {
    return SellerProductsState(
      status: status ?? this.status,
      products: products ?? this.products,
      filter: filter ?? this.filter,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, products, filter, error];
}

class SellerProductsBloc
    extends Bloc<SellerProductsEvent, SellerProductsState> {
  SellerProductsBloc(this._repo) : super(const SellerProductsState()) {
    on<SellerProductsRequested>(_onRequested);
    on<SellerProductsFilterChanged>(
        (e, emit) => emit(state.copyWith(filter: e.filter)));
    on<SellerProductsSearchChanged>(
      (e, emit) {
        final filter = state.filter.copyWith(
          search: e.query,
          clearSearch: e.query.isEmpty,
        );
        emit(state.copyWith(filter: filter));
      },
    );
    on<SellerProductArchived>(_onArchived);
    on<SellerProductSubmitted>(_onSubmitted);
    on<_SellerProductsRefreshed>(
        (e, emit) => emit(state.copyWith(products: e.products)));

    _sub = _repo.watch().listen((products) {
      add(_SellerProductsRefreshed(products));
    });
  }

  final SellerProductRepository _repo;
  StreamSubscription<List<SellerProduct>>? _sub;

  Future<void> _onRequested(
    SellerProductsRequested event,
    Emitter<SellerProductsState> emit,
  ) async {
    emit(state.copyWith(
        status: SellerProductsStatus.loading, clearError: true));
    try {
      // Pull a generous first page; further pagination lands in Sprint 8.
      final res = await _repo.list(perPage: 50);
      emit(state.copyWith(
          status: SellerProductsStatus.ready, products: res.items));
    } catch (e) {
      emit(state.copyWith(
          status: SellerProductsStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onArchived(
    SellerProductArchived event,
    Emitter<SellerProductsState> emit,
  ) async {
    emit(state.copyWith(status: SellerProductsStatus.mutating));
    try {
      await _repo.archive(event.id);
      // _SellerProductsRefreshed via stream will update the list.
      emit(state.copyWith(status: SellerProductsStatus.ready));
    } catch (e) {
      emit(state.copyWith(
          status: SellerProductsStatus.ready, error: e.toString()));
    }
  }

  Future<void> _onSubmitted(
    SellerProductSubmitted event,
    Emitter<SellerProductsState> emit,
  ) async {
    emit(state.copyWith(status: SellerProductsStatus.mutating));
    try {
      await _repo.submitForReview(event.id);
      emit(state.copyWith(status: SellerProductsStatus.ready));
    } catch (e) {
      emit(state.copyWith(
          status: SellerProductsStatus.ready, error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
