import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../../shared/repositories/supabase_category_repository.dart';
import '../../../../shared/repositories/supabase_product_data_source.dart';

enum ProductListStatus { initial, loading, loaded, failure }

class ProductListState extends Equatable {
  const ProductListState({
    this.status = ProductListStatus.initial,
    this.products = const [],
    this.subcategories = const [],
    this.selectedSubcategoryId,
    this.filter = const ProductSearchFilter(),
    this.error,
  });

  final ProductListStatus status;
  final List<SupabaseProductModel> products;

  /// Sibling subcategories under the current category. Empty when the
  /// category has none — the screen hides its chip bar in that case.
  final List<SubcategoryModel> subcategories;

  /// `null` means the "All" tab is active (no subcategory filter applied).
  /// A concrete id narrows the products to that subcategory.
  final String? selectedSubcategoryId;

  /// Facet filters (price, color, in-stock, discount, delivery + sort)
  /// applied on top of the category/subcategory selection. Shared model
  /// with search — see [ProductSearchFilter].
  final ProductSearchFilter filter;

  final String? error;

  ProductListState copyWith({
    ProductListStatus? status,
    List<SupabaseProductModel>? products,
    List<SubcategoryModel>? subcategories,
    String? selectedSubcategoryId,
    ProductSearchFilter? filter,
    String? error,
    bool clearSelectedSubcategory = false,
    bool clearError = false,
  }) {
    return ProductListState(
      status: status ?? this.status,
      products: products ?? this.products,
      subcategories: subcategories ?? this.subcategories,
      selectedSubcategoryId: clearSelectedSubcategory
          ? null
          : (selectedSubcategoryId ?? this.selectedSubcategoryId),
      filter: filter ?? this.filter,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        products,
        subcategories,
        selectedSubcategoryId,
        filter,
        error,
      ];
}

class ProductListCubit extends Cubit<ProductListState> {
  ProductListCubit(this._productSource, this._categorySource)
      : super(const ProductListState());

  final SupabaseProductDataSource _productSource;
  final CategoryDataSource _categorySource;

  String _categoryId = '';

  /// First-load entry point. Pulls both the category list (to discover the
  /// current category's subcategories) and the product list in parallel so
  /// the chip bar and grid arrive together — avoiding a flash of "no chips"
  /// followed by chips popping in once the grid is already rendered.
  Future<void> load({
    required String categoryId,
    String? subcategoryId,
  }) async {
    _categoryId = categoryId;
    emit(
      state.copyWith(
        status: ProductListStatus.loading,
        selectedSubcategoryId: subcategoryId,
        clearSelectedSubcategory: subcategoryId == null,
        clearError: true,
      ),
    );
    try {
      final results = await Future.wait([
        _productSource.listByCategory(
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          filter: state.filter,
        ),
        _categorySource.list(),
      ]);
      final products = results[0] as List<SupabaseProductModel>;
      final categories = results[1] as List<CategoryModel>;
      // Locate the current category's subcategories without throwing when
      // it isn't found — defensive against a stale categoryId from a deep
      // link or a category that has been removed.
      final match = categories
          .where((c) => c.id == categoryId)
          .cast<CategoryModel?>()
          .firstWhere((_) => true, orElse: () => null);
      emit(
        state.copyWith(
          status: ProductListStatus.loaded,
          products: products,
          subcategories: match?.subcategories ?? const [],
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ProductListStatus.failure,
          error: e.toString(),
        ),
      );
    }
  }

  /// Switch the active subcategory tab. Pass `null` to clear the filter
  /// ("All" tab). Skips the round-trip when the user re-taps the active
  /// chip so the grid doesn't flicker through a loading shimmer.
  Future<void> selectSubcategory(String? subcategoryId) async {
    if (subcategoryId == state.selectedSubcategoryId) return;
    await _refetch(
      subcategoryId: subcategoryId,
      filter: state.filter,
      clearSubcategory: subcategoryId == null,
    );
  }

  /// Apply a new facet filter (price / colors / in-stock / discount /
  /// delivery / sort). The subcategory selection survives unchanged so
  /// the user's narrowing context is preserved.
  Future<void> applyFilter(ProductSearchFilter filter) async {
    if (filter == state.filter) return;
    await _refetch(
      subcategoryId: state.selectedSubcategoryId,
      filter: filter,
      clearSubcategory: state.selectedSubcategoryId == null,
    );
  }

  Future<void> _refetch({
    required String? subcategoryId,
    required ProductSearchFilter filter,
    required bool clearSubcategory,
  }) async {
    emit(
      state.copyWith(
        status: ProductListStatus.loading,
        selectedSubcategoryId: subcategoryId,
        clearSelectedSubcategory: clearSubcategory,
        filter: filter,
        clearError: true,
      ),
    );
    try {
      final products = await _productSource.listByCategory(
        categoryId: _categoryId,
        subcategoryId: subcategoryId,
        filter: filter,
      );
      // The user may have tapped another chip or tweaked the filter while
      // this request was in flight — drop the result if so, otherwise the
      // grid would briefly show stale data from the wrong selection.
      if (state.selectedSubcategoryId != subcategoryId ||
          state.filter != filter) {
        return;
      }
      emit(
        state.copyWith(status: ProductListStatus.loaded, products: products),
      );
    } catch (e) {
      if (state.selectedSubcategoryId != subcategoryId ||
          state.filter != filter) {
        return;
      }
      emit(
        state.copyWith(
          status: ProductListStatus.failure,
          error: e.toString(),
        ),
      );
    }
  }
}
