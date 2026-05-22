import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/cart_item_model.dart';
import '../../../../shared/models/supabase_product_model.dart';
import '../../../../shared/repositories/cart_repository.dart';

// ── Events ─────────────────────────────────────────────────────────────────

sealed class CartEvent extends Equatable {
  const CartEvent();
  @override
  List<Object?> get props => const [];
}

/// Initial fetch of the cart. The bloc also wires a `watchItems` subscription
/// in its constructor so subsequent updates from the repository (e.g.
/// auth-state-driven delegate swaps in [HybridCartRepository]) flow in
/// without an explicit reload.
class LoadCart extends CartEvent {
  const LoadCart();
}

class AddToCart extends CartEvent {
  const AddToCart(this.product, {this.quantity = 1, this.selectedColor});
  final SupabaseProductModel product;
  final int quantity;

  /// Canonical colour slug chosen on the product page. Null when the product
  /// has no colour palette; mandatory (non-null) when it does.
  final String? selectedColor;

  @override
  List<Object?> get props => [product.id, quantity, selectedColor];
}

class UpdateQuantity extends CartEvent {
  const UpdateQuantity({required this.productId, required this.newQuantity});
  final String productId;
  final int newQuantity;
  @override
  List<Object?> get props => [productId, newQuantity];
}

class RemoveFromCart extends CartEvent {
  const RemoveFromCart(this.productId);
  final String productId;
  @override
  List<Object?> get props => [productId];
}

class ClearCart extends CartEvent {
  const ClearCart();
}

class _CartItemsChanged extends CartEvent {
  const _CartItemsChanged(this.items);
  final List<CartItemModel> items;
  @override
  List<Object?> get props => [items];
}

// ── State ──────────────────────────────────────────────────────────────────

enum CartStatus { initial, loading, ready, mutating, failure }

class CartState extends Equatable {
  const CartState({
    this.status = CartStatus.initial,
    this.items = const [],
    this.error,
  });

  final CartStatus status;
  final List<CartItemModel> items;
  final String? error;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Total quantity across all rows. Used by the bottom-nav badge.
  int get totalUnits => items.fold<int>(0, (sum, it) => sum + it.quantity);

  /// Sum of `price * quantity` over every cart line.
  double get totalPrice =>
      items.fold<double>(0, (sum, it) => sum + it.lineTotal);

  CartState copyWith({
    CartStatus? status,
    List<CartItemModel>? items,
    String? error,
    bool clearError = false,
  }) {
    return CartState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, items, error];
}

// ── Bloc ───────────────────────────────────────────────────────────────────

/// Cart bloc backed by a [CartRepository] (typically [HybridCartRepository]).
///
/// All mutating handlers run optimistically: the predicted next state is
/// emitted immediately, then the repository is called and the resulting
/// snapshot replaces the optimistic state. On failure we roll back.
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc(this._repo) : super(const CartState()) {
    on<LoadCart>(_onLoad);
    on<AddToCart>(_onAdd);
    on<UpdateQuantity>(_onUpdate);
    on<RemoveFromCart>(_onRemove);
    on<ClearCart>(_onClear);
    on<_CartItemsChanged>(
      (e, emit) => emit(
        state.copyWith(
          status: CartStatus.ready,
          items: e.items,
          clearError: true,
        ),
      ),
    );

    _sub = _repo.watchItems().listen((items) {
      add(_CartItemsChanged(items));
    });
  }

  final CartRepository _repo;
  StreamSubscription<List<CartItemModel>>? _sub;

  Future<void> _onLoad(LoadCart event, Emitter<CartState> emit) async {
    emit(state.copyWith(status: CartStatus.loading, clearError: true));
    try {
      final items = await _repo.fetchItems();
      emit(state.copyWith(status: CartStatus.ready, items: items));
    } catch (e) {
      emit(state.copyWith(status: CartStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onAdd(AddToCart event, Emitter<CartState> emit) async {
    final previous = state.items;
    final qtyClamped = event.quantity.clamp(1, 99);

    // Optimistic merge: bump quantity if the product is already in the
    // cart, otherwise insert a new snapshot row. A product occupies one line
    // regardless of colour — re-adding with a different colour updates the
    // line's colour to the latest pick (one product = one colour per order).
    final existingIdx = previous.indexWhere(
      (it) => it.productId == event.product.id,
    );
    final List<CartItemModel> optimistic;
    if (existingIdx >= 0) {
      optimistic = List<CartItemModel>.of(previous);
      final existing = optimistic[existingIdx];
      optimistic[existingIdx] = existing.copyWith(
        quantity: (existing.quantity + qtyClamped).clamp(1, 99),
        selectedColor: event.selectedColor,
      );
    } else {
      optimistic = [
        ...previous,
        CartItemModel.fromProduct(
          event.product,
          quantity: qtyClamped,
          selectedColor: event.selectedColor,
        ),
      ];
    }

    emit(state.copyWith(status: CartStatus.mutating, items: optimistic));
    try {
      await _repo.addProduct(
        event.product,
        quantity: qtyClamped,
        selectedColor: event.selectedColor,
      );
      // The repository emits the canonical state via watchItems(); we still
      // surface a "ready" status here so listeners not subscribed to
      // intermediate mutating frames see a clean transition.
      emit(state.copyWith(status: CartStatus.ready));
    } catch (e) {
      emit(
        state.copyWith(
          status: CartStatus.ready,
          items: previous,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onUpdate(UpdateQuantity event, Emitter<CartState> emit) async {
    final previous = state.items;

    if (event.newQuantity <= 0) {
      add(RemoveFromCart(event.productId));
      return;
    }

    final clamped = event.newQuantity.clamp(1, 99);
    final optimistic = [
      for (final it in previous)
        if (it.productId == event.productId)
          it.copyWith(quantity: clamped)
        else
          it,
    ];

    emit(state.copyWith(status: CartStatus.mutating, items: optimistic));
    try {
      await _repo.updateProductQuantity(event.productId, clamped);
      emit(state.copyWith(status: CartStatus.ready));
    } catch (e) {
      emit(
        state.copyWith(
          status: CartStatus.ready,
          items: previous,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onRemove(RemoveFromCart event, Emitter<CartState> emit) async {
    final previous = state.items;
    final optimistic = previous
        .where((it) => it.productId != event.productId)
        .toList();

    emit(state.copyWith(status: CartStatus.mutating, items: optimistic));
    try {
      await _repo.removeProduct(event.productId);
      emit(state.copyWith(status: CartStatus.ready));
    } catch (e) {
      emit(
        state.copyWith(
          status: CartStatus.ready,
          items: previous,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onClear(ClearCart event, Emitter<CartState> emit) async {
    final previous = state.items;
    emit(state.copyWith(status: CartStatus.mutating, items: const []));
    try {
      await _repo.clear();
      emit(state.copyWith(status: CartStatus.ready));
    } catch (e) {
      emit(
        state.copyWith(
          status: CartStatus.ready,
          items: previous,
          error: e.toString(),
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
