import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result/result.dart';
import '../../../../shared/models/cancel_reason.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/repositories/order_repository.dart';

sealed class OrderDetailEvent extends Equatable {
  const OrderDetailEvent();
  @override
  List<Object?> get props => const [];
}

class OrderDetailRequested extends OrderDetailEvent {
  const OrderDetailRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class OrderDetailCancelled extends OrderDetailEvent {
  const OrderDetailCancelled({required this.reasonCode, this.reasonText});
  final String reasonCode;
  final String? reasonText;
  @override
  List<Object?> get props => [reasonCode, reasonText];
}

class OrderFeeAdjustmentApproved extends OrderDetailEvent {
  const OrderFeeAdjustmentApproved();
}

class OrderFeeAdjustmentRejected extends OrderDetailEvent {
  const OrderFeeAdjustmentRejected();
}

class _OrderRealtimeUpdated extends OrderDetailEvent {
  const _OrderRealtimeUpdated(this.order);
  final Order order;
  @override
  List<Object?> get props => [order];
}

enum OrderDetailStatus { initial, loading, ready, mutating, failure }

class OrderDetailState extends Equatable {
  const OrderDetailState({
    this.status = OrderDetailStatus.initial,
    this.order,
    this.error,
    this.realtimeConnected = false,
  });

  final OrderDetailStatus status;
  final Order? order;
  final String? error;
  final bool realtimeConnected;

  OrderDetailState copyWith({
    OrderDetailStatus? status,
    Order? order,
    String? error,
    bool clearError = false,
    bool? realtimeConnected,
  }) {
    return OrderDetailState(
      status: status ?? this.status,
      order: order ?? this.order,
      error: clearError ? null : (error ?? this.error),
      realtimeConnected: realtimeConnected ?? this.realtimeConnected,
    );
  }

  @override
  List<Object?> get props => [status, order, error, realtimeConnected];
}

class OrderDetailBloc extends Bloc<OrderDetailEvent, OrderDetailState> {
  OrderDetailBloc(this._repo) : super(const OrderDetailState()) {
    on<OrderDetailRequested>(_onRequested);
    on<OrderDetailCancelled>(_onCancelled);
    on<OrderFeeAdjustmentApproved>(_onFeeApproved);
    on<OrderFeeAdjustmentRejected>(_onFeeRejected);
    on<_OrderRealtimeUpdated>(
      (event, emit) => emit(state.copyWith(order: event.order)),
    );
  }

  final OrderRepository _repo;
  StreamSubscription<Order>? _sub;

  /// Reference data (cancellation reason list) for the cancel-reason sheet —
  /// not bloc state, just a pass-through so the widget uses the bloc's
  /// already-injected repo instead of resolving one itself. `showCancelReasonSheet`
  /// is a shared widget also fed by still-throw repos (seller), so this bridges
  /// back to a throw on `Err` rather than changing that shared contract.
  Future<List<CancelReason>> fetchCancelReasons() => _repo
      .fetchCancelReasons()
      .then((r) => r.fold(ok: (v) => v, err: (f) => throw f));

  Future<void> _onRequested(
    OrderDetailRequested event,
    Emitter<OrderDetailState> emit,
  ) async {
    emit(state.copyWith(status: OrderDetailStatus.loading, clearError: true));
    final result = await _repo.getById(event.id);
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: OrderDetailStatus.ready, order: value));
        // Subscribe to realtime updates so status changes from another device
        // (or the seller) appear in 1-2 seconds without a manual refresh.
        await _sub?.cancel();
        _sub = _repo.watch(event.id).listen((updated) {
          add(_OrderRealtimeUpdated(updated));
        });
        emit(state.copyWith(realtimeConnected: true));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: OrderDetailStatus.failure,
            error: failure.message,
          ),
        );
    }
  }

  Future<void> _onCancelled(
    OrderDetailCancelled event,
    Emitter<OrderDetailState> emit,
  ) async {
    final order = state.order;
    if (order == null) return;
    emit(state.copyWith(status: OrderDetailStatus.mutating));
    final result = await _repo.cancel(
      order.id,
      reasonCode: event.reasonCode,
      reasonText: event.reasonText,
    );
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: OrderDetailStatus.ready, order: value));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: OrderDetailStatus.ready,
            error: failure.message,
          ),
        );
    }
  }

  Future<void> _onFeeApproved(
    OrderFeeAdjustmentApproved event,
    Emitter<OrderDetailState> emit,
  ) async {
    final order = state.order;
    if (order == null) return;
    emit(state.copyWith(status: OrderDetailStatus.mutating));
    final result = await _repo.approveFeeAdjustment(order.id);
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: OrderDetailStatus.ready, order: value));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: OrderDetailStatus.ready,
            error: failure.message,
          ),
        );
    }
  }

  Future<void> _onFeeRejected(
    OrderFeeAdjustmentRejected event,
    Emitter<OrderDetailState> emit,
  ) async {
    final order = state.order;
    if (order == null) return;
    emit(state.copyWith(status: OrderDetailStatus.mutating));
    final result = await _repo.rejectFeeAdjustment(order.id);
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: OrderDetailStatus.ready, order: value));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: OrderDetailStatus.ready,
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
