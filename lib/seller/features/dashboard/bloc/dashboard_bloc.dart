import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/dashboard_snapshot.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/repositories/seller_dashboard_repository.dart';

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => const [];
}

class DashboardRequested extends DashboardEvent {
  const DashboardRequested();
}

class DashboardNewOrderReceived extends DashboardEvent {
  const DashboardNewOrderReceived(this.order);
  final Order order;
  @override
  List<Object?> get props => [order.id];
}

class DashboardNewOrderCleared extends DashboardEvent {
  const DashboardNewOrderCleared();
}

enum DashboardStatus { initial, loading, ready, failure }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.snapshot,
    this.lastNewOrder,
    this.error,
  });

  final DashboardStatus status;
  final DashboardSnapshot? snapshot;

  /// One-shot transient — UI listens for changes here and surfaces a
  /// snackbar / haptic on every new value, then clears it.
  final Order? lastNewOrder;
  final String? error;

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardSnapshot? snapshot,
    Order? lastNewOrder,
    String? error,
    bool clearError = false,
    bool clearLastNewOrder = false,
  }) {
    return DashboardState(
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      lastNewOrder: clearLastNewOrder
          ? null
          : (lastNewOrder ?? this.lastNewOrder),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, snapshot, lastNewOrder?.id, error];
}

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc(this._repo) : super(const DashboardState()) {
    on<DashboardRequested>(_onRequested);
    on<DashboardNewOrderReceived>(_onNewOrder);
    on<DashboardNewOrderCleared>((_, emit) =>
        emit(state.copyWith(clearLastNewOrder: true)));

    _sub = _repo.newOrders().listen((order) {
      add(DashboardNewOrderReceived(order));
    });
  }

  final SellerDashboardRepository _repo;
  StreamSubscription<Order>? _sub;

  Future<void> _onRequested(
    DashboardRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(status: DashboardStatus.loading, clearError: true));
    try {
      final snapshot = await _repo.snapshot();
      emit(state.copyWith(status: DashboardStatus.ready, snapshot: snapshot));
    } catch (e) {
      emit(state.copyWith(
          status: DashboardStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onNewOrder(
    DashboardNewOrderReceived event,
    Emitter<DashboardState> emit,
  ) async {
    final snap = state.snapshot;
    final updatedSnap = snap == null
        ? null
        : DashboardSnapshot(
            todaysOrders: snap.todaysOrders + 1,
            todaysRevenue: snap.todaysRevenue + event.order.grandTotal,
            pendingOrdersCount: snap.pendingOrdersCount + 1,
            activeProductsCount: snap.activeProductsCount,
            tariff: snap.tariff,
            recentOrders: [event.order, ...snap.recentOrders].take(5).toList(),
            last30Days: snap.last30Days,
          );
    emit(state.copyWith(snapshot: updatedSnap, lastNewOrder: event.order));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
