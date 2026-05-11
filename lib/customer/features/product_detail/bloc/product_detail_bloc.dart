import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/product.dart';
import '../../../../shared/repositories/product_repository.dart';

sealed class ProductDetailEvent extends Equatable {
  const ProductDetailEvent();
  @override
  List<Object?> get props => const [];
}

class ProductDetailRequested extends ProductDetailEvent {
  const ProductDetailRequested(this.slug);
  final String slug;
  @override
  List<Object?> get props => [slug];
}

class ProductDetailFavoriteSyncRequested extends ProductDetailEvent {
  const ProductDetailFavoriteSyncRequested({required this.isFavorite});
  final bool isFavorite;
  @override
  List<Object?> get props => [isFavorite];
}

enum ProductDetailStatus { initial, loading, ready, failure }

class ProductDetailState extends Equatable {
  const ProductDetailState({
    this.status = ProductDetailStatus.initial,
    this.product,
    this.error,
  });

  final ProductDetailStatus status;
  final Product? product;
  final String? error;

  ProductDetailState copyWith({
    ProductDetailStatus? status,
    Product? product,
    String? error,
    bool clearError = false,
  }) {
    return ProductDetailState(
      status: status ?? this.status,
      product: product ?? this.product,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, product, error];
}

class ProductDetailBloc extends Bloc<ProductDetailEvent, ProductDetailState> {
  ProductDetailBloc(this._repo) : super(const ProductDetailState()) {
    on<ProductDetailRequested>(_onRequested);
    on<ProductDetailFavoriteSyncRequested>(_onFavSync);
  }

  final ProductRepository _repo;

  Future<void> _onRequested(
    ProductDetailRequested event,
    Emitter<ProductDetailState> emit,
  ) async {
    emit(state.copyWith(status: ProductDetailStatus.loading, clearError: true));
    try {
      final product = await _repo.getBySlug(event.slug);
      emit(state.copyWith(
        status: ProductDetailStatus.ready,
        product: product,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProductDetailStatus.failure,
        error: e.toString(),
      ));
    }
  }

  void _onFavSync(
    ProductDetailFavoriteSyncRequested event,
    Emitter<ProductDetailState> emit,
  ) {
    final p = state.product;
    if (p == null) return;
    if (p.isFavorite == event.isFavorite) return;
    emit(state.copyWith(product: p.copyWith(isFavorite: event.isFavorite)));
  }
}
