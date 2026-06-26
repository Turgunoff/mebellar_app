import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/result/result.dart';
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
  const SellerOrderActionCancelled({required this.reasonCode, this.reasonText});
  final String reasonCode;
  final String? reasonText;
  @override
  List<Object?> get props => [reasonCode, reasonText];
}

class SellerOrderDeliveryFeeSet extends SellerOrderDetailEvent {
  const SellerOrderDeliveryFeeSet({required this.fee});
  final num fee;
  @override
  List<Object?> get props => [fee];
}

/// Accept a pending order with the EXACT per-address delivery fee. The backend
/// stamps the fee and branches the status (cash → confirmed, online →
/// awaiting_payment); we just refresh with the returned order.
class SellerOrderAcceptSubmitted extends SellerOrderDetailEvent {
  const SellerOrderAcceptSubmitted({required this.deliveryFee});
  final int deliveryFee;
  @override
  List<Object?> get props => [deliveryFee];
}

class _SellerOrderRealtimeUpdated extends SellerOrderDetailEvent {
  const _SellerOrderRealtimeUpdated(this.order);
  final Order order;
  @override
  List<Object?> get props => [order];
}

enum SellerOrderDetailStatus {
  initial,
  loading,
  ready,
  mutating,
  failure,
  settingFee,
}

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
  /// Cancellation is shown alongside while the order is non-terminal
  /// (`status.sellerCancellable`).
  List<OrderStatus> get availableForward =>
      order?.status.sellerForwardTransitions ?? const [];
  bool get canCancel => order?.status.sellerCancellable ?? false;

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
  SellerOrderDetailBloc(
    this._repo, {
    this.onUpdated,
    AnalyticsService? analytics,
  }) : _analytics = analytics,
       super(const SellerOrderDetailState()) {
    on<SellerOrderDetailRequested>(_onRequested);
    on<SellerOrderActionConfirmed>(_runAction((id) => _repo.confirm(id)));
    on<SellerOrderActionMarkPreparing>(
      _runAction((id) => _repo.markPreparing(id)),
    );
    on<SellerOrderActionMarkShipped>(_runAction((id) => _repo.markShipped(id)));
    on<SellerOrderActionMarkDelivered>(
      _runAction((id) => _repo.markDelivered(id)),
    );
    on<SellerOrderActionCancelled>((event, emit) async {
      await _runAction(
        (id) => _repo.cancel(
          id,
          reasonCode: event.reasonCode,
          reasonText: event.reasonText,
        ),
      ).call(event, emit);
    });
    on<SellerOrderDeliveryFeeSet>(_onDeliveryFeeSet);
    on<SellerOrderAcceptSubmitted>(_onAcceptSubmitted);
    on<_SellerOrderRealtimeUpdated>(
      (e, emit) => emit(state.copyWith(order: e.order)),
    );
  }

  final SellerOrderRepository _repo;
  final AnalyticsService? _analytics;

  /// Optional callback so the parent orders list BLoC can mirror updates.
  final void Function(Order order)? onUpdated;
  StreamSubscription<Order>? _sub;

  Future<void> _onRequested(
    SellerOrderDetailRequested event,
    Emitter<SellerOrderDetailState> emit,
  ) async {
    emit(
      state.copyWith(status: SellerOrderDetailStatus.loading, clearError: true),
    );
    final result = await _repo.getById(event.id);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(status: SellerOrderDetailStatus.ready, order: value),
        );
        await _sub?.cancel();
        _sub = _repo
            .watch(event.id)
            .listen((u) => add(_SellerOrderRealtimeUpdated(u)));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: SellerOrderDetailStatus.failure,
            error: failure.message,
          ),
        );
    }
  }

  Future<void> _onAcceptSubmitted(
    SellerOrderAcceptSubmitted event,
    Emitter<SellerOrderDetailState> emit,
  ) async {
    final order = state.order;
    if (order == null) return;
    emit(state.copyWith(status: SellerOrderDetailStatus.settingFee));
    final result = await _repo.accept(order.id, deliveryFee: event.deliveryFee);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(status: SellerOrderDetailStatus.ready, order: value),
        );
        onUpdated?.call(value);
      case Err(:final failure):
        emit(
          state.copyWith(
            status: SellerOrderDetailStatus.ready,
            error: failure.message,
          ),
        );
    }
  }

  Future<void> _onDeliveryFeeSet(
    SellerOrderDeliveryFeeSet event,
    Emitter<SellerOrderDetailState> emit,
  ) async {
    final order = state.order;
    if (order == null) return;
    emit(state.copyWith(status: SellerOrderDetailStatus.settingFee));
    final result = await _repo.setDeliveryFee(order.id, fee: event.fee);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(status: SellerOrderDetailStatus.ready, order: value),
        );
        onUpdated?.call(value);
      case Err(:final failure):
        emit(
          state.copyWith(
            status: SellerOrderDetailStatus.ready,
            error: failure.message,
          ),
        );
    }
  }

  EventHandler<SellerOrderDetailEvent, SellerOrderDetailState> _runAction(
    Future<Result<Order>> Function(String id) op,
  ) {
    return (event, emit) async {
      final order = state.order;
      if (order == null) return;
      final fromStatus = order.status.code;
      emit(state.copyWith(status: SellerOrderDetailStatus.mutating));
      final result = await op(order.id);
      switch (result) {
        case Ok(:final value):
          emit(
            state.copyWith(status: SellerOrderDetailStatus.ready, order: value),
          );
          onUpdated?.call(value);
          if (value.status.code != fromStatus) {
            unawaited(
              _analytics?.sellerOrderStatusChanged(
                orderId: order.id,
                fromStatus: fromStatus,
                toStatus: value.status.code,
              ),
            );
          }
        case Err(:final failure):
          emit(
            state.copyWith(
              status: SellerOrderDetailStatus.ready,
              error: failure.message,
            ),
          );
      }
    };
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
