import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/result/result.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/repositories/order_repository.dart';

class UnpaidOrderState extends Equatable {
  const UnpaidOrderState({this.order, this.receivedAt});

  final Order? order;
  final DateTime? receivedAt;

  @override
  List<Object?> get props => [order?.id, order?.status, order?.paymentStatus, receivedAt];
}

class UnpaidOrderCubit extends Cubit<UnpaidOrderState> {
  UnpaidOrderCubit(this._orders, this._isSignedIn)
      : super(const UnpaidOrderState());

  final OrderRepository _orders;
  final bool Function() _isSignedIn;

  Future<void> refresh() async {
    if (!_isSignedIn()) {
      emit(const UnpaidOrderState());
      return;
    }
    final result = await _orders.fetchAwaitingPaymentOrder();
    switch (result) {
      case Ok(:final value):
        if (value == null || !value.awaitsOnlinePayment) {
          emit(const UnpaidOrderState());
          return;
        }
        emit(UnpaidOrderState(order: value, receivedAt: DateTime.now()));
      case Err():
        // Keep the last known banner on transient failures.
        break;
    }
  }

  void clear() => emit(const UnpaidOrderState());

  void clearIfOrder(String orderId) {
    final current = state.order;
    if (current != null && current.id == orderId) {
      clear();
    }
  }
}

UnpaidOrderCubit createUnpaidOrderCubit() => UnpaidOrderCubit(
      sl<OrderRepository>(),
      () => sl<TokenStore>().current != null,
    );
