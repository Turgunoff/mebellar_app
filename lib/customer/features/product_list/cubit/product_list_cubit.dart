import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_error_messages.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/repositories/category_data_source.dart';
import '../../../../shared/repositories/product_data_source.dart';

enum ProductListStatus { initial, loading, loaded, failure }

class ProductListState extends Equatable {
  const ProductListState({
    this.status = ProductListStatus.initial,
    this.products = const [],
    this.subcategories = const [],
    this.selectedSubcategoryId,
    this.filter = const ProductSearchFilter(),
    this.hasMore = false,
    this.loadingMore = false,
    this.error,
  });

  final ProductListStatus status;
  final List<ProductModel> products;

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

  /// Whether another page remains to fetch. Drives the scroll trigger + footer.
  final bool hasMore;

  /// A next-page append is in flight (footer spinner). Also guards against
  /// re-entrant [ProductListCubit.loadMore] calls a fast scroll fires.
  final bool loadingMore;

  final String? error;

  ProductListState copyWith({
    ProductListStatus? status,
    List<ProductModel>? products,
    List<SubcategoryModel>? subcategories,
    String? selectedSubcategoryId,
    ProductSearchFilter? filter,
    bool? hasMore,
    bool? loadingMore,
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
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
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
    hasMore,
    loadingMore,
    error,
  ];
}

class ProductListCubit extends Cubit<ProductListState> {
  ProductListCubit(this._productSource, this._categorySource)
    : super(const ProductListState());

  final ProductDataSource _productSource;
  final CategoryDataSource _categorySource;

  String _categoryId = '';

  static const int _pageSize = kCategoryPageSize;

  // Server-side pagination cursor — the count of *raw* rows fetched so far for
  // the current selection. Advanced by the raw page size (before any dedup) so
  // a catalog shift between pages can never stall the window. Reset to the
  // first page's size on every full (re)load / subcategory / filter change.
  int _categoryOffset = 0;

  // Hard 5s ceiling — mirrors HomeBloc so a dead connection surfaces the
  // blocking modal fast instead of waiting out Dio's 30s receive timeout.
  static const Duration _loadTimeout = Duration(seconds: 5);

  // More rows remain when the last page came back full AND the cursor hasn't
  // reached the catalog-wide total for the active filter. Keyed off the raw
  // page size so a short page is the only "last page" signal.
  bool _moreAfter(ProductFeedPage page) =>
      page.items.length >= _pageSize && _categoryOffset < page.total;

  /// First-load entry point. Pulls both the category list (to discover the
  /// current category's subcategories) and the product list in parallel so
  /// the chip bar and grid arrive together — avoiding a flash of "no chips"
  /// followed by chips popping in once the grid is already rendered.
  Future<void> load({required String categoryId, String? subcategoryId}) async {
    _categoryId = categoryId;

    // The selection this background fetch is built for. The cache-paint below
    // renders an interactive screen *before* the network lands, so the user can
    // tap a subcategory chip, apply a filter, or scroll into a `loadMore` while
    // the refresh is still in flight. We snapshot here and re-check after the
    // await so a stale first-page result can't clobber a newer selection or the
    // pages `loadMore` has already appended (mirrors the guards in
    // [loadMore] / [_refetch]).
    final requestedSubcategoryId = subcategoryId;
    final requestedFilter = state.filter;

    // Cache-first paint: when the user taps "all" of a category from the
    // home grid (no subcategory, default filter) we hit the cached listing
    // and emit `loaded` synchronously. Subcategories piggyback on the
    // categories cache. Filtered/subcategory entries skip this — the cache
    // only stores the default view.
    final canPeek = subcategoryId == null && state.filter.isDefault;
    final cachedPage = canPeek
        ? _productSource.peekByCategory(categoryId)
        : null;
    final cachedCategories = _categorySource.peek();
    final cachedSubs = cachedCategories
        ?.where((c) => c.id == categoryId)
        .cast<CategoryModel?>()
        .firstWhere((_) => true, orElse: () => null)
        ?.subcategories;
    final hasCache = cachedPage != null && cachedSubs != null;
    if (hasCache) {
      _categoryOffset = cachedPage.items.length;
      emit(
        state.copyWith(
          status: ProductListStatus.loaded,
          products: cachedPage.items,
          subcategories: cachedSubs,
          selectedSubcategoryId: subcategoryId,
          clearSelectedSubcategory: subcategoryId == null,
          hasMore: _moreAfter(cachedPage),
          loadingMore: false,
          clearError: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: ProductListStatus.loading,
          selectedSubcategoryId: subcategoryId,
          clearSelectedSubcategory: subcategoryId == null,
          loadingMore: false,
          clearError: true,
        ),
      );
    }

    try {
      final results = await Future.wait([
        _productSource.listByCategory(
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          filter: state.filter,
          limit: _pageSize,
          offset: 0,
        ),
        _categorySource.list(),
      ]).timeout(_loadTimeout);
      if (isClosed) return;
      final page = results[0] as ProductFeedPage;
      final categories = results[1] as List<CategoryModel>;
      // Locate the current category's subcategories without throwing when
      // it isn't found — defensive against a stale categoryId from a deep
      // link or a category that has been removed.
      final match = categories
          .where((c) => c.id == categoryId)
          .cast<CategoryModel?>()
          .firstWhere((_) => true, orElse: () => null);
      // If the user narrowed the selection or paginated further while this
      // refresh was in flight, its first-page result is stale: keep the live
      // products + cursor (owned now by [_refetch] / [loadMore]) and refresh
      // only the category-level subcategory chips. `products.length > page
      // length` catches an already-appended next page; `loadingMore` catches an
      // append still in flight.
      final selectionChanged =
          state.selectedSubcategoryId != requestedSubcategoryId ||
          state.filter != requestedFilter;
      final listGrew =
          state.loadingMore || state.products.length > page.items.length;
      if (selectionChanged || listGrew) {
        emit(state.copyWith(subcategories: match?.subcategories ?? const []));
        return;
      }
      _categoryOffset = page.items.length;
      emit(
        state.copyWith(
          status: ProductListStatus.loaded,
          products: page.items,
          subcategories: match?.subcategories ?? const [],
          hasMore: _moreAfter(page),
          loadingMore: false,
        ),
      );
    } catch (e) {
      if (isClosed ||
          state.selectedSubcategoryId != requestedSubcategoryId ||
          state.filter != requestedFilter) {
        return;
      }
      // Keep the cached page visible on a refresh failure — surface a hard
      // failure state only when we had nothing to paint to begin with.
      if (hasCache) {
        emit(state.copyWith(error: apiErrorMessage(e)));
      } else {
        emit(
          state.copyWith(
            status: ProductListStatus.failure,
            error: apiErrorMessage(e),
          ),
        );
      }
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

  /// Append the next page to the bottom of the current list. No-op unless the
  /// list is a healthy, settled page with more rows left; the synchronous
  /// `loadingMore` flip makes a burst of scroll-triggered calls collapse to a
  /// single fetch (the cubit has no event-transformer to dedupe for it).
  Future<void> loadMore() async {
    if (state.status != ProductListStatus.loaded ||
        !state.hasMore ||
        state.loadingMore) {
      return;
    }
    // Snapshot the selection this page belongs to — a subcategory/filter swap
    // mid-fetch must discard the stale append rather than splice it under the
    // wrong selection.
    final subcategoryId = state.selectedSubcategoryId;
    final filter = state.filter;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _productSource
          .listByCategory(
            categoryId: _categoryId,
            subcategoryId: subcategoryId,
            filter: filter,
            limit: _pageSize,
            offset: _categoryOffset,
          )
          .timeout(_loadTimeout);
      if (isClosed ||
          state.selectedSubcategoryId != subcategoryId ||
          state.filter != filter) {
        return;
      }
      // Advance the raw cursor by what the server returned BEFORE the dedup, so
      // a fully-overlapping page still moves the window forward.
      _categoryOffset += page.items.length;
      // Dedup by id so a catalog shift between pages can't double-render a
      // product; `seen.add` returns false for ids already loaded.
      final seen = state.products.map((p) => p.id).toSet();
      final fresh = page.items.where((p) => seen.add(p.id)).toList();
      emit(
        state.copyWith(
          products: [...state.products, ...fresh],
          hasMore: _moreAfter(page),
          loadingMore: false,
        ),
      );
    } catch (e) {
      if (isClosed ||
          state.selectedSubcategoryId != subcategoryId ||
          state.filter != filter) {
        return;
      }
      // Soft-fail: keep what we have and clear the spinner. The next scroll
      // re-arms the trigger, letting the user retry by simply scrolling again.
      emit(state.copyWith(loadingMore: false));
    }
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
        loadingMore: false,
        clearError: true,
      ),
    );
    try {
      final page = await _productSource
          .listByCategory(
            categoryId: _categoryId,
            subcategoryId: subcategoryId,
            filter: filter,
            limit: _pageSize,
            offset: 0,
          )
          .timeout(_loadTimeout);
      // The user may have tapped another chip or tweaked the filter while
      // this request was in flight — drop the result if so, otherwise the
      // grid would briefly show stale data from the wrong selection.
      if (isClosed ||
          state.selectedSubcategoryId != subcategoryId ||
          state.filter != filter) {
        return;
      }
      _categoryOffset = page.items.length;
      emit(
        state.copyWith(
          status: ProductListStatus.loaded,
          products: page.items,
          hasMore: _moreAfter(page),
          loadingMore: false,
        ),
      );
    } catch (e) {
      if (isClosed ||
          state.selectedSubcategoryId != subcategoryId ||
          state.filter != filter) {
        return;
      }
      emit(
        state.copyWith(
          status: ProductListStatus.failure,
          error: apiErrorMessage(e),
        ),
      );
    }
  }
}
