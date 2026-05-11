import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/models/cart_item_model.dart';
import '../../../../shared/repositories/cart_repository.dart';

enum CheckoutPayment { cash, card }

enum CheckoutStatus { idle, submitting, success, failure }

class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.idle,
    this.items = const [],
    this.payment = CheckoutPayment.cash,
    this.deliveryAddress = '',
    this.error,
  });

  final CheckoutStatus status;
  final List<CartItemModel> items;
  final CheckoutPayment payment;
  final String deliveryAddress;
  final String? error;

  static const double deliveryFee = 50000;

  bool get hasAddress => deliveryAddress.trim().isNotEmpty;

  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.lineTotal);

  double get grandTotal => subtotal + deliveryFee;

  CheckoutState copyWith({
    CheckoutStatus? status,
    List<CartItemModel>? items,
    CheckoutPayment? payment,
    String? deliveryAddress,
    String? error,
    bool clearError = false,
  }) =>
      CheckoutState(
        status: status ?? this.status,
        items: items ?? this.items,
        payment: payment ?? this.payment,
        deliveryAddress: deliveryAddress ?? this.deliveryAddress,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, items, payment, deliveryAddress, error];
}

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required List<CartItemModel> items,
    required SupabaseClient supabase,
    required CartRepository cartRepo,
  })  : _supabase = supabase,
        _cartRepo = cartRepo,
        super(CheckoutState(items: items));

  final SupabaseClient _supabase;
  final CartRepository _cartRepo;

  void selectPayment(CheckoutPayment payment) =>
      emit(state.copyWith(payment: payment));

  void updateAddress(String address) =>
      emit(state.copyWith(deliveryAddress: address.trim()));

  Future<void> submit(String userId) async {
    if (state.status == CheckoutStatus.submitting) return;
    emit(state.copyWith(status: CheckoutStatus.submitting, clearError: true));

    try {
      final row = await _supabase
          .from('orders')
          .insert({
            'user_id': userId,
            'total_amount': state.grandTotal,
            'status': 'pending',
            'delivery_address': state.deliveryAddress,
          })
          .select('id')
          .single();

      final orderId = row['id'] as String;

      await _supabase.from('order_items').insert(
            state.items
                .map((it) => {
                      'order_id': orderId,
                      'product_id': it.productId,
                      'quantity': it.quantity,
                      'price': it.productPrice,
                    })
                .toList(),
          );

      await _cartRepo.clear();

      emit(state.copyWith(status: CheckoutStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: CheckoutStatus.failure,
        error: e.toString(),
      ));
    }
  }
}
