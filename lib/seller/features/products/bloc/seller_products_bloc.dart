import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/result/result.dart';
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

class SellerProductRestored extends SellerProductsEvent {
  const SellerProductRestored(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class SellerProductDeleted extends SellerProductsEvent {
  const SellerProductDeleted(this.id);
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
    // Sellers land on the live catalogue ("Tasdiqlangan") by default;
    // "Barchasi" stays one tap away and search auto-widens to it.
    this.filter = const SellerProductFilter(
      statuses: {SellerProductStatus.approved},
    ),
    this.statusCounts = const {},
    this.error,
  });

  final SellerProductsStatus status;
  final List<SellerProduct> products;
  final SellerProductFilter filter;

  /// Whole-catalogue per-status totals from the backend (not the fetched
  /// page), kept in step locally on archive/restore/delete. Backs the
  /// filter-chip badges. Empty until the first fetch lands.
  final Map<SellerProductStatus, int> statusCounts;
  final String? error;

  List<SellerProduct> get visibleProducts =>
      products.where(filter.matches).toList();

  /// Badge value for a chip — null (hidden) until counts arrive; [status]
  /// null means "Barchasi" (the sum of every bucket).
  int? countFor(SellerProductStatus? status) {
    if (statusCounts.isEmpty) return null;
    if (status == null) {
      return statusCounts.values.fold<int>(0, (sum, n) => sum + n);
    }
    return statusCounts[status] ?? 0;
  }

  SellerProductsState copyWith({
    SellerProductsStatus? status,
    List<SellerProduct>? products,
    SellerProductFilter? filter,
    Map<SellerProductStatus, int>? statusCounts,
    String? error,
    bool clearError = false,
  }) {
    return SellerProductsState(
      status: status ?? this.status,
      products: products ?? this.products,
      filter: filter ?? this.filter,
      statusCounts: statusCounts ?? this.statusCounts,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, products, filter, statusCounts, error];
}

class SellerProductsBloc
    extends Bloc<SellerProductsEvent, SellerProductsState> {
  SellerProductsBloc(this._repo, {AnalyticsService? analytics})
    : _analytics = analytics,
      super(const SellerProductsState()) {
    on<SellerProductsRequested>(_onRequested);
    on<SellerProductsFilterChanged>(
      (e, emit) => emit(state.copyWith(filter: e.filter)),
    );
    on<SellerProductsSearchChanged>((e, emit) {
      // The first keystroke widens scope to "Barchasi" so an SKU lookup finds
      // the product whatever its status (archived, rejected, …). Only the
      // empty→non-empty transition resets it — a chip tapped mid-search keeps
      // narrowing the results.
      final startedSearch =
          e.query.isNotEmpty && (state.filter.search ?? '').isEmpty;
      final filter = state.filter.copyWith(
        search: e.query,
        clearSearch: e.query.isEmpty,
        statuses: startedSearch ? const {} : null,
      );
      emit(state.copyWith(filter: filter));
    });
    on<SellerProductArchived>(_onArchived);
    on<SellerProductRestored>(_onRestored);
    on<SellerProductDeleted>(_onDeleted);
    on<SellerProductSubmitted>(_onSubmitted);
    // watch() emits the full (unfiltered) catalogue — mock only, the Woody
    // stream is empty — so the chip badges can be recomputed from it directly.
    on<_SellerProductsRefreshed>(
      (e, emit) => emit(
        state.copyWith(
          products: e.products,
          statusCounts: _countedByStatus(e.products),
        ),
      ),
    );

    _sub = _repo.watch().listen((products) {
      add(_SellerProductsRefreshed(products));
    });
  }

  final SellerProductRepository _repo;
  final AnalyticsService? _analytics;
  StreamSubscription<List<SellerProduct>>? _sub;

  Future<void> _onRequested(
    SellerProductsRequested event,
    Emitter<SellerProductsState> emit,
  ) async {
    emit(
      state.copyWith(status: SellerProductsStatus.loading, clearError: true),
    );
    // Pull a generous first page; further pagination lands in Sprint 8.
    final result = await _repo.list(perPage: 50);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: SellerProductsStatus.ready,
            products: value.items,
            statusCounts: value.statusCounts,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: SellerProductsStatus.failure,
            error: failure.message,
          ),
        );
    }
  }

  Future<void> _onArchived(
    SellerProductArchived event,
    Emitter<SellerProductsState> emit,
  ) async {
    emit(state.copyWith(status: SellerProductsStatus.mutating));
    final previous = _statusOf(event.id);
    final result = await _repo.archive(event.id);
    switch (result) {
      case Ok(:final value):
        // The Woody repo's watch() is empty, so patch the returned row into
        // the list directly rather than relying on a stream refresh (the
        // mock's _emit() converges to the same result).
        emit(
          state.copyWith(
            status: SellerProductsStatus.ready,
            products: _replaced(value),
            statusCounts: _shiftedCounts(from: previous, to: value.status),
          ),
        );
        // Archive is our soft-delete — track it as productDeleted so the
        // analytics funnel sees a single "removed from catalog" signal.
        unawaited(_analytics?.productDeleted(productId: event.id));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: SellerProductsStatus.ready,
            error: failure.message,
          ),
        );
    }
  }

  Future<void> _onRestored(
    SellerProductRestored event,
    Emitter<SellerProductsState> emit,
  ) async {
    emit(state.copyWith(status: SellerProductsStatus.mutating));
    final previous = _statusOf(event.id);
    final result = await _repo.restore(event.id);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: SellerProductsStatus.ready,
            products: _replaced(value),
            statusCounts: _shiftedCounts(from: previous, to: value.status),
          ),
        );
        // Restore puts the product back into the review queue — the closest
        // signal we have on this surface is a product update.
        unawaited(_analytics?.productUpdated(productId: event.id));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: SellerProductsStatus.ready,
            error: failure.message,
          ),
        );
    }
  }

  Future<void> _onDeleted(
    SellerProductDeleted event,
    Emitter<SellerProductsState> emit,
  ) async {
    emit(state.copyWith(status: SellerProductsStatus.mutating));
    final previous = _statusOf(event.id);
    final result = await _repo.delete(event.id);
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            status: SellerProductsStatus.ready,
            products: [
              for (final p in state.products)
                if (p.id != event.id) p,
            ],
            statusCounts: _shiftedCounts(from: previous),
          ),
        );
        unawaited(_analytics?.productDeleted(productId: event.id));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: SellerProductsStatus.ready,
            error: failure.message,
          ),
        );
    }
  }

  /// Returns a copy of the current product list with [updated] swapped in by
  /// id. If the id isn't present (e.g. archived from a detail screen opened
  /// before the list loaded) the list is returned unchanged.
  List<SellerProduct> _replaced(SellerProduct updated) => [
    for (final p in state.products)
      if (p.id == updated.id) updated else p,
  ];

  SellerProductStatus? _statusOf(String id) =>
      state.products.where((p) => p.id == id).firstOrNull?.status;

  static Map<SellerProductStatus, int> _countedByStatus(
    List<SellerProduct> products,
  ) {
    final counts = <SellerProductStatus, int>{};
    for (final p in products) {
      counts[p.status] = (counts[p.status] ?? 0) + 1;
    }
    return counts;
  }

  /// Moves one product between chip-badge buckets so the counts stay true to
  /// the DB without a refetch — mirrors how mutations patch the list locally.
  /// A null [from]/[to] means the product entered/left the catalogue.
  Map<SellerProductStatus, int> _shiftedCounts({
    SellerProductStatus? from,
    SellerProductStatus? to,
  }) {
    if (state.statusCounts.isEmpty || from == to) return state.statusCounts;
    final counts = Map<SellerProductStatus, int>.from(state.statusCounts);
    if (from != null) {
      final current = counts[from] ?? 0;
      if (current > 1) {
        counts[from] = current - 1;
      } else {
        counts.remove(from);
      }
    }
    if (to != null) {
      counts[to] = (counts[to] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _onSubmitted(
    SellerProductSubmitted event,
    Emitter<SellerProductsState> emit,
  ) async {
    emit(state.copyWith(status: SellerProductsStatus.mutating));
    final result = await _repo.submitForReview(event.id);
    switch (result) {
      case Ok():
        emit(state.copyWith(status: SellerProductsStatus.ready));
        // "Submit for review" is the closest signal we have to a product
        // update on this surface — fire it so the dashboard sees the edit.
        unawaited(_analytics?.productUpdated(productId: event.id));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: SellerProductsStatus.ready,
            error: failure.message,
          ),
        );
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
