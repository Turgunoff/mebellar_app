import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_error_messages.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/models/order_status.dart';
import '../../../../shared/repositories/order_repository.dart';

enum OrdersTab { all, active, completed, cancelled }

extension OrdersTabFilter on OrdersTab {
  bool matches(Order order) {
    return switch (this) {
      OrdersTab.all => true,
      OrdersTab.active => order.status.isActive,
      OrdersTab.completed => order.status == OrderStatus.delivered,
      OrdersTab.cancelled => order.status == OrderStatus.cancelled,
    };
  }
}

sealed class OrdersEvent extends Equatable {
  const OrdersEvent();
  @override
  List<Object?> get props => const [];
}

class OrdersRequested extends OrdersEvent {
  const OrdersRequested();
}

class OrdersTabChanged extends OrdersEvent {
  const OrdersTabChanged(this.tab);
  final OrdersTab tab;
  @override
  List<Object?> get props => [tab];
}

enum OrdersStatus { initial, loading, ready, failure }

class OrdersState extends Equatable {
  const OrdersState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.tab = OrdersTab.all,
    this.error,
  });

  final OrdersStatus status;
  final List<Order> orders;
  final OrdersTab tab;
  final String? error;

  List<Order> get visibleOrders =>
      orders.where((o) => tab.matches(o)).toList();

  OrdersState copyWith({
    OrdersStatus? status,
    List<Order>? orders,
    OrdersTab? tab,
    String? error,
    bool clearError = false,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      tab: tab ?? this.tab,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, orders, tab, error];
}

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc(this._repo) : super(const OrdersState()) {
    // ROADMAP B.7 — droppable: ignores a refresh that arrives while a fetch
    // is still running (e.g. rapid pull-to-refresh) instead of queueing it.
    on<OrdersRequested>(_onRequested, transformer: droppable());
    on<OrdersTabChanged>(
        (event, emit) => emit(state.copyWith(tab: event.tab)));
  }

  final OrderRepository _repo;

  // Hard 5s ceiling — mirrors HomeBloc so a dead connection surfaces the
  // blocking modal fast instead of waiting out Dio's 30s receive timeout.
  static const Duration _loadTimeout = Duration(seconds: 5);

  Future<void> _onRequested(
    OrdersRequested event,
    Emitter<OrdersState> emit,
  ) async {
    // Only flash the shimmer when there's nothing on screen. A refresh over an
    // existing list stays put — and because we transition through `loading`
    // whenever the list is empty, a repeated failure still re-emits
    // (failure → loading → failure) so the retry modal's spinner can't hang on
    // a de-duped state.
    if (state.orders.isEmpty) {
      emit(state.copyWith(status: OrdersStatus.loading, clearError: true));
    }
    try {
      final list = await _repo.list().timeout(_loadTimeout);
      emit(
        state.copyWith(
          status: OrdersStatus.ready,
          orders: list,
          clearError: true,
        ),
      );
    } catch (e) {
      if (state.orders.isNotEmpty) {
        // Graceful: keep the list visible, surface the error as a top-toast.
        emit(state.copyWith(error: apiErrorMessage(e)));
      } else {
        emit(
          state.copyWith(
            status: OrdersStatus.failure,
            error: apiErrorMessage(e),
          ),
        );
      }
    }
  }
}
