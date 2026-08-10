import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/i18n/app_locale_controller.dart';
import '../../../../core/i18n/locale_refetch.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/repositories/favorites_repository.dart';

sealed class FavoritesEvent extends Equatable {
  const FavoritesEvent();
  @override
  List<Object?> get props => const [];
}

class FavoritesRequested extends FavoritesEvent {
  const FavoritesRequested({this.refresh = false, this.completer});

  /// Re-fetch without flipping into `loading` — the rendered list stays
  /// until fresh data lands. Used by the locale-switch silent refetch.
  final bool refresh;

  /// Completed when the fetch settles (success or failure). Pull-to-refresh
  /// awaits this instead of the bloc stream — an unchanged list is deduped
  /// by Equatable, so a state emission may never come.
  final Completer<void>? completer;

  @override
  List<Object?> get props => [refresh];
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

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState>
    with LocaleRefetch<FavoritesState> {
  FavoritesBloc(
    this._repo, {
    AppLocaleController? localeController,
    Stream<bool>? authChanges,
  }) : super(const FavoritesState()) {
    on<FavoritesRequested>(_onRequested);
    on<FavoriteToggled>(_onToggled);
    on<FavoriteRemoved>(_onRemoved);
    on<_FavoritesIdsChanged>(_onIdsChanged);

    _sub = _repo.watchIds().listen((ids) => add(_FavoritesIdsChanged(ids)));
    // Server favorites are invisible to a signed-out session (401 → empty),
    // so refetch on every real signed-in/out flip: login pulls the account's
    // list, logout clears it. `distinct` drops token-refresh repeats.
    _authSub = authChanges?.distinct().listen(
      (_) => add(const FavoritesRequested(refresh: true)),
    );
    watchLocale(localeController);
  }

  final FavoritesRepository _repo;
  StreamSubscription<Set<String>>? _sub;
  StreamSubscription<bool>? _authSub;

  // Favourite products carry backend-localised names; reload them in the
  // new language without blanking the rendered list.
  @override
  void onLocaleChanged() => add(const FavoritesRequested(refresh: true));

  Future<void> _onRequested(
    FavoritesRequested event,
    Emitter<FavoritesState> emit,
  ) async {
    final silent = event.refresh && state.products.isNotEmpty;
    if (!silent) {
      emit(state.copyWith(status: FavoritesStatus.loading, clearError: true));
    }
    try {
      final list = await _repo.list();
      emit(
        state.copyWith(
          status: FavoritesStatus.ready,
          products: list,
          ids: list.map((p) => p.id).toSet(),
        ),
      );
    } catch (e) {
      // A failed silent refetch keeps the old-language list on screen.
      if (silent) return;
      emit(
        state.copyWith(
          status: FavoritesStatus.failure,
          error: apiErrorMessage(e),
        ),
      );
    } finally {
      final completer = event.completer;
      if (completer != null && !completer.isCompleted) completer.complete();
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
        emit(
          state.copyWith(products: list, ids: list.map((p) => p.id).toSet()),
        );
      }
    } catch (e) {
      // Roll back only this product against the CURRENT ids — `state.ids`
      // was re-emitted unchanged before (a no-op "rollback" that left a
      // failed toggle looking saved), and a full pre-toggle snapshot could
      // clobber ids updated mid-flight by a concurrent refetch.
      final rolledBack = Set<String>.from(state.ids);
      if (wasFav) {
        rolledBack.add(event.product.id);
      } else {
        rolledBack.remove(event.product.id);
      }
      emit(state.copyWith(ids: rolledBack, error: apiErrorMessage(e)));
    }
  }

  Future<void> _onRemoved(
    FavoriteRemoved event,
    Emitter<FavoritesState> emit,
  ) async {
    final previousProducts = state.products;
    final previousIds = state.ids;
    emit(
      state.copyWith(
        products: previousProducts
            .where((p) => p.id != event.productId)
            .toList(),
        ids: Set<String>.from(previousIds)..remove(event.productId),
      ),
    );
    try {
      await _repo.remove(event.productId);
    } catch (e) {
      emit(
        state.copyWith(
          products: previousProducts,
          ids: previousIds,
          error: apiErrorMessage(e),
        ),
      );
    }
  }

  void _onIdsChanged(_FavoritesIdsChanged event, Emitter<FavoritesState> emit) {
    emit(state.copyWith(ids: event.ids));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _authSub?.cancel();
    return super.close();
  }
}
