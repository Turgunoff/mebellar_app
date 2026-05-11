import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    on<OrdersRequested>(_onRequested);
    on<OrdersTabChanged>(
        (event, emit) => emit(state.copyWith(tab: event.tab)));
  }

  final OrderRepository _repo;

  Future<void> _onRequested(
    OrdersRequested event,
    Emitter<OrdersState> emit,
  ) async {
    emit(state.copyWith(status: OrdersStatus.loading, clearError: true));
    try {
      final list = await _repo.list();
      emit(state.copyWith(status: OrdersStatus.ready, orders: list));
    } catch (e) {
      emit(state.copyWith(status: OrdersStatus.failure, error: e.toString()));
    }
  }
}
