import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/order.dart';
import '../../../../shared/models/order_status.dart';
import '../../../../shared/repositories/seller_order_repository.dart';

enum SellerOrdersTab { newTab, active, done, cancelled }

extension SellerOrdersTabFilter on SellerOrdersTab {
  bool matches(Order order) {
    return switch (this) {
      SellerOrdersTab.newTab => order.status == OrderStatus.pending,
      SellerOrdersTab.active => order.status == OrderStatus.confirmed ||
          order.status == OrderStatus.preparing ||
          order.status == OrderStatus.shipped,
      SellerOrdersTab.done => order.status == OrderStatus.delivered,
      SellerOrdersTab.cancelled => order.status == OrderStatus.cancelled,
    };
  }
}

sealed class SellerOrdersEvent extends Equatable {
  const SellerOrdersEvent();
  @override
  List<Object?> get props => const [];
}

class SellerOrdersRequested extends SellerOrdersEvent {
  const SellerOrdersRequested();
}

class SellerOrdersTabChanged extends SellerOrdersEvent {
  const SellerOrdersTabChanged(this.tab);
  final SellerOrdersTab tab;
  @override
  List<Object?> get props => [tab];
}

class SellerOrdersUnreadCleared extends SellerOrdersEvent {
  const SellerOrdersUnreadCleared();
}

class _SellerOrderInserted extends SellerOrdersEvent {
  const _SellerOrderInserted(this.order);
  final Order order;
  @override
  List<Object?> get props => [order.id];
}

class _SellerOrderUpdated extends SellerOrdersEvent {
  const _SellerOrderUpdated(this.order);
  final Order order;
  @override
  List<Object?> get props => [order.id, order.status];
}

enum SellerOrdersStatus { initial, loading, ready, failure }

class SellerOrdersState extends Equatable {
  const SellerOrdersState({
    this.status = SellerOrdersStatus.initial,
    this.orders = const [],
    this.tab = SellerOrdersTab.newTab,
    this.unreadNewIds = const <String>{},
    this.error,
  });

  final SellerOrdersStatus status;
  final List<Order> orders;
  final SellerOrdersTab tab;

  /// Ids of pending orders that arrived since the user last opened the
  /// "New" tab — drives the badge count on the bottom-nav and tab.
  final Set<String> unreadNewIds;
  final String? error;

  List<Order> get visibleOrders =>
      orders.where((o) => tab.matches(o)).toList();

  int get badgeCount => unreadNewIds.length;

  SellerOrdersState copyWith({
    SellerOrdersStatus? status,
    List<Order>? orders,
    SellerOrdersTab? tab,
    Set<String>? unreadNewIds,
    String? error,
    bool clearError = false,
  }) {
    return SellerOrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      tab: tab ?? this.tab,
      unreadNewIds: unreadNewIds ?? this.unreadNewIds,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, orders, tab, unreadNewIds, error];
}

class SellerOrdersBloc extends Bloc<SellerOrdersEvent, SellerOrdersState> {
  SellerOrdersBloc(this._repo) : super(const SellerOrdersState()) {
    on<SellerOrdersRequested>(_onRequested);
    on<SellerOrdersTabChanged>((event, emit) {
      // Switching to the "new" tab clears the unread badge.
      final clearUnread = event.tab == SellerOrdersTab.newTab;
      emit(state.copyWith(
        tab: event.tab,
        unreadNewIds: clearUnread ? const {} : state.unreadNewIds,
      ));
    });
    on<SellerOrdersUnreadCleared>(
        (_, emit) => emit(state.copyWith(unreadNewIds: const {})));
    on<_SellerOrderInserted>(_onInserted);
    on<_SellerOrderUpdated>(_onUpdated);

    _newSub = _repo.newOrders().listen((order) => add(_SellerOrderInserted(order)));
  }

  final SellerOrderRepository _repo;
  StreamSubscription<Order>? _newSub;

  Future<void> _onRequested(
    SellerOrdersRequested event,
    Emitter<SellerOrdersState> emit,
  ) async {
    emit(state.copyWith(
        status: SellerOrdersStatus.loading, clearError: true));
    try {
      final list = await _repo.list();
      emit(state.copyWith(status: SellerOrdersStatus.ready, orders: list));
    } catch (e) {
      emit(state.copyWith(
          status: SellerOrdersStatus.failure, error: e.toString()));
    }
  }

  void _onInserted(
    _SellerOrderInserted event,
    Emitter<SellerOrdersState> emit,
  ) {
    if (state.orders.any((o) => o.id == event.order.id)) return;
    final nextOrders = [event.order, ...state.orders];
    final unread = state.tab == SellerOrdersTab.newTab
        ? state.unreadNewIds
        : {...state.unreadNewIds, event.order.id};
    emit(state.copyWith(orders: nextOrders, unreadNewIds: unread));
  }

  void _onUpdated(
    _SellerOrderUpdated event,
    Emitter<SellerOrdersState> emit,
  ) {
    final idx = state.orders.indexWhere((o) => o.id == event.order.id);
    if (idx < 0) return;
    final next = List<Order>.from(state.orders);
    next[idx] = event.order;
    final unread = Set<String>.from(state.unreadNewIds);
    if (event.order.status != OrderStatus.pending) {
      unread.remove(event.order.id);
    }
    emit(state.copyWith(orders: next, unreadNewIds: unread));
  }

  /// Allow other BLoCs (e.g. SellerOrderDetailBloc) to push a fresh order
  /// snapshot into the list when the seller takes an action without
  /// requiring a full refetch.
  void pushOrderUpdate(Order order) => add(_SellerOrderUpdated(order));

  @override
  Future<void> close() async {
    await _newSub?.cancel();
    return super.close();
  }
}
