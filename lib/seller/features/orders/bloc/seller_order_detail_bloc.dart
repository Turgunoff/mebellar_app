import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/order.dart';
import '../../../../shared/models/order_status.dart';
import '../../../../shared/repositories/seller_order_repository.dart';

sealed class SellerOrderDetailEvent extends Equatable {
  const SellerOrderDetailEvent();
  @override
  List<Object?> get props => const [];
}

class SellerOrderDetailRequested extends SellerOrderDetailEvent {
  const SellerOrderDetailRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class SellerOrderActionConfirmed extends SellerOrderDetailEvent {
  const SellerOrderActionConfirmed();
}

class SellerOrderActionMarkPreparing extends SellerOrderDetailEvent {
  const SellerOrderActionMarkPreparing();
}

class SellerOrderActionMarkShipped extends SellerOrderDetailEvent {
  const SellerOrderActionMarkShipped();
}

class SellerOrderActionMarkDelivered extends SellerOrderDetailEvent {
  const SellerOrderActionMarkDelivered();
}

class SellerOrderActionCancelled extends SellerOrderDetailEvent {
  const SellerOrderActionCancelled(this.reason);
  final String reason;
  @override
  List<Object?> get props => [reason];
}

class _SellerOrderRealtimeUpdated extends SellerOrderDetailEvent {
  const _SellerOrderRealtimeUpdated(this.order);
  final Order order;
  @override
  List<Object?> get props => [order];
}

enum SellerOrderDetailStatus { initial, loading, ready, mutating, failure }

class SellerOrderDetailState extends Equatable {
  const SellerOrderDetailState({
    this.status = SellerOrderDetailStatus.initial,
    this.order,
    this.error,
  });

  final SellerOrderDetailStatus status;
  final Order? order;
  final String? error;

  /// Forward transitions the seller can trigger from the current status.
  /// Cancellation is always shown alongside as long as `status.cancellable`.
  List<OrderStatus> get availableForward =>
      order?.status.sellerForwardTransitions ?? const [];
  bool get canCancel => order?.status.cancellable ?? false;

  SellerOrderDetailState copyWith({
    SellerOrderDetailStatus? status,
    Order? order,
    String? error,
    bool clearError = false,
  }) {
    return SellerOrderDetailState(
      status: status ?? this.status,
      order: order ?? this.order,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, order, error];
}

class SellerOrderDetailBloc
    extends Bloc<SellerOrderDetailEvent, SellerOrderDetailState> {
  SellerOrderDetailBloc(this._repo, {this.onUpdated})
      : super(const SellerOrderDetailState()) {
    on<SellerOrderDetailRequested>(_onRequested);
    on<SellerOrderActionConfirmed>(_runAction((id) => _repo.confirm(id)));
    on<SellerOrderActionMarkPreparing>(
        _runAction((id) => _repo.markPreparing(id)));
    on<SellerOrderActionMarkShipped>(
        _runAction((id) => _repo.markShipped(id)));
    on<SellerOrderActionMarkDelivered>(
        _runAction((id) => _repo.markDelivered(id)));
    on<SellerOrderActionCancelled>((event, emit) async {
      await _runAction((id) => _repo.cancel(id, reason: event.reason)).call(
          event, emit);
    });
    on<_SellerOrderRealtimeUpdated>(
        (e, emit) => emit(state.copyWith(order: e.order)));
  }

  final SellerOrderRepository _repo;

  /// Optional callback so the parent orders list BLoC can mirror updates.
  final void Function(Order order)? onUpdated;
  StreamSubscription<Order>? _sub;

  Future<void> _onRequested(
    SellerOrderDetailRequested event,
    Emitter<SellerOrderDetailState> emit,
  ) async {
    emit(state.copyWith(
        status: SellerOrderDetailStatus.loading, clearError: true));
    try {
      final order = await _repo.getById(event.id);
      emit(state.copyWith(
          status: SellerOrderDetailStatus.ready, order: order));
      await _sub?.cancel();
      _sub = _repo
          .watch(event.id)
          .listen((u) => add(_SellerOrderRealtimeUpdated(u)));
    } catch (e) {
      emit(state.copyWith(
          status: SellerOrderDetailStatus.failure, error: e.toString()));
    }
  }

  EventHandler<SellerOrderDetailEvent, SellerOrderDetailState> _runAction(
    Future<Order> Function(String id) op,
  ) {
    return (event, emit) async {
      final order = state.order;
      if (order == null) return;
      emit(state.copyWith(status: SellerOrderDetailStatus.mutating));
      try {
        final updated = await op(order.id);
        emit(state.copyWith(
            status: SellerOrderDetailStatus.ready, order: updated));
        onUpdated?.call(updated);
      } catch (e) {
        emit(state.copyWith(
          status: SellerOrderDetailStatus.ready,
          error: e.toString(),
        ));
      }
    };
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
