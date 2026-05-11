import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/supabase_product_model.dart';
import '../../../../shared/repositories/supabase_product_data_source.dart';

enum ProductListStatus { initial, loading, loaded, failure }

class ProductListState extends Equatable {
  const ProductListState({
    this.status = ProductListStatus.initial,
    this.products = const [],
    this.error,
  });

  final ProductListStatus status;
  final List<SupabaseProductModel> products;
  final String? error;

  ProductListState copyWith({
    ProductListStatus? status,
    List<SupabaseProductModel>? products,
    String? error,
    bool clearError = false,
  }) {
    return ProductListState(
      status: status ?? this.status,
      products: products ?? this.products,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, products, error];
}

class ProductListCubit extends Cubit<ProductListState> {
  ProductListCubit(this._source) : super(const ProductListState());

  final SupabaseProductDataSource _source;

  Future<void> load({required String categoryId, String? subcategoryId}) async {
    emit(state.copyWith(status: ProductListStatus.loading, clearError: true));
    try {
      final products = await _source.listByCategory(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
      );
      emit(state.copyWith(status: ProductListStatus.loaded, products: products));
    } catch (e) {
      emit(state.copyWith(
        status: ProductListStatus.failure,
        error: e.toString(),
      ));
    }
  }
}
