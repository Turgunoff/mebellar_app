import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/product.dart';
import '../../../../shared/repositories/product_repository.dart';

sealed class CatalogEvent extends Equatable {
  const CatalogEvent();
  @override
  List<Object?> get props => const [];
}

class CatalogRequested extends CatalogEvent {
  const CatalogRequested({this.refresh = false});
  final bool refresh;
  @override
  List<Object?> get props => [refresh];
}

class CatalogFilterChanged extends CatalogEvent {
  const CatalogFilterChanged(this.filter);
  final ProductFilter filter;
  @override
  List<Object?> get props => [filter];
}

class CatalogNextPageRequested extends CatalogEvent {
  const CatalogNextPageRequested();
}

enum CatalogStatus { initial, loading, ready, loadingMore, failure }

class CatalogState extends Equatable {
  const CatalogState({
    this.status = CatalogStatus.initial,
    this.filter = const ProductFilter(),
    this.products = const [],
    this.page = 1,
    this.hasNext = true,
    this.error,
  });

  final CatalogStatus status;
  final ProductFilter filter;
  final List<Product> products;
  final int page;
  final bool hasNext;
  final String? error;

  CatalogState copyWith({
    CatalogStatus? status,
    ProductFilter? filter,
    List<Product>? products,
    int? page,
    bool? hasNext,
    String? error,
    bool clearError = false,
  }) {
    return CatalogState(
      status: status ?? this.status,
      filter: filter ?? this.filter,
      products: products ?? this.products,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, filter, products, page, hasNext, error];
}

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc(this._repo, {ProductFilter initialFilter = const ProductFilter()})
      : super(CatalogState(filter: initialFilter)) {
    on<CatalogRequested>(_onRequested);
    on<CatalogFilterChanged>(_onFilterChanged);
    on<CatalogNextPageRequested>(_onNextPage);
  }

  final ProductRepository _repo;

  Future<void> _onRequested(
    CatalogRequested event,
    Emitter<CatalogState> emit,
  ) async {
    emit(state.copyWith(
      status: CatalogStatus.loading,
      page: 1,
      products: const [],
      hasNext: true,
      clearError: true,
    ));
    try {
      final res = await _repo.list(filter: state.filter, page: 1);
      emit(state.copyWith(
        status: CatalogStatus.ready,
        products: res.items,
        page: res.page,
        hasNext: res.hasNext,
      ));
    } catch (e) {
      emit(state.copyWith(status: CatalogStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onFilterChanged(
    CatalogFilterChanged event,
    Emitter<CatalogState> emit,
  ) async {
    emit(state.copyWith(filter: event.filter));
    add(const CatalogRequested());
  }

  Future<void> _onNextPage(
    CatalogNextPageRequested event,
    Emitter<CatalogState> emit,
  ) async {
    if (!state.hasNext || state.status == CatalogStatus.loadingMore) return;
    emit(state.copyWith(status: CatalogStatus.loadingMore, clearError: true));
    try {
      final res = await _repo.list(
        filter: state.filter,
        page: state.page + 1,
      );
      emit(state.copyWith(
        status: CatalogStatus.ready,
        products: [...state.products, ...res.items],
        page: res.page,
        hasNext: res.hasNext,
      ));
    } catch (e) {
      // Keep existing products visible; surface a one-shot error toast.
      emit(state.copyWith(status: CatalogStatus.ready, error: e.toString()));
    }
  }
}
