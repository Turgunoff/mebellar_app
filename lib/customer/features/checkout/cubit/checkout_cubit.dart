import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/models/cart_item_model.dart';
import '../../../../shared/repositories/cart_repository.dart';

enum CheckoutPayment { cash, card }

enum CheckoutStatus { idle, submitting, success, failure }

/// A group of cart items that belong to the same shop. Each group results in
/// one `orders` row so the seller sees only their own items.
class ShopOrderGroup extends Equatable {
  const ShopOrderGroup({
    required this.shopId,
    required this.shopName,
    required this.items,
  });

  /// Empty string when shop info is unknown (old snapshot without shop_id).
  final String shopId;
  final String shopName;
  final List<CartItemModel> items;

  double get subtotal =>
      items.fold(0.0, (s, it) => s + it.lineTotal);

  @override
  List<Object?> get props => [shopId, items];
}

class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.idle,
    this.groups = const [],
    this.payment = CheckoutPayment.cash,
    this.deliveryAddress = '',
    this.placedOrderIds = const [],
    this.error,
  });

  final CheckoutStatus status;
  final List<ShopOrderGroup> groups;
  final CheckoutPayment payment;
  final String deliveryAddress;

  /// Order IDs created during [submit] — populated on success.
  final List<String> placedOrderIds;
  final String? error;

  bool get hasAddress => deliveryAddress.trim().isNotEmpty;

  double get subtotal =>
      groups.fold(0.0, (s, g) => s + g.subtotal);

  /// Delivery fee is determined by each seller after placement — no upfront
  /// charge. Grand total at this stage equals items subtotal only.
  double get grandTotal => subtotal;

  List<CartItemModel> get allItems =>
      [for (final g in groups) ...g.items];

  CheckoutState copyWith({
    CheckoutStatus? status,
    List<ShopOrderGroup>? groups,
    CheckoutPayment? payment,
    String? deliveryAddress,
    List<String>? placedOrderIds,
    String? error,
    bool clearError = false,
  }) =>
      CheckoutState(
        status: status ?? this.status,
        groups: groups ?? this.groups,
        payment: payment ?? this.payment,
        deliveryAddress: deliveryAddress ?? this.deliveryAddress,
        placedOrderIds: placedOrderIds ?? this.placedOrderIds,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props =>
      [status, groups, payment, deliveryAddress, placedOrderIds, error];
}

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required List<CartItemModel> items,
    required SupabaseClient supabase,
    required CartRepository cartRepo,
  })  : _supabase = supabase,
        _cartRepo = cartRepo,
        super(CheckoutState(groups: _groupByShop(items)));

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
      final placedIds = <String>[];

      for (final group in state.groups) {
        final row = await _supabase
            .from('orders')
            .insert({
              'user_id': userId,
              'total_amount': group.subtotal,
              'status': 'pending',
              'delivery_address': state.deliveryAddress,
            })
            .select('id')
            .single();

        final orderId = row['id'] as String;

        await _supabase.from('order_items').insert(
              group.items
                  .map((it) => {
                        'order_id': orderId,
                        'product_id': it.productId,
                        'quantity': it.quantity,
                        'price': it.productPrice,
                      })
                  .toList(),
            );

        placedIds.add(orderId);
      }

      await _cartRepo.clear();
      emit(state.copyWith(
        status: CheckoutStatus.success,
        placedOrderIds: placedIds,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CheckoutStatus.failure,
        error: e.toString(),
      ));
    }
  }

  /// Groups items by [CartItemModel.shopId]. Items without a shopId are
  /// pooled under key `''` so they still produce a valid order.
  static List<ShopOrderGroup> _groupByShop(List<CartItemModel> items) {
    final map = <String, List<CartItemModel>>{};
    for (final item in items) {
      final key = item.shopId ?? '';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map.entries.map((e) {
      final name = e.value.first.shopName ?? '';
      return ShopOrderGroup(shopId: e.key, shopName: name, items: e.value);
    }).toList(growable: false);
  }
}
