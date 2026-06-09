import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/logging/talker.dart';
import '../../../../shared/repositories/profile_orders_repository.dart';

class ProfileOrdersState extends Equatable {
  const ProfileOrdersState({this.orders = const [], this.isLoading = false});

  final List<Map<String, dynamic>> orders;
  final bool isLoading;

  // Derived counts — always reflect latest state without extra fields.
  // Status codes mirror `OrderStatus` in shared/models/order_status.dart:
  // pending · confirmed · preparing · shipped · delivered · cancelled.
  int get pendingCount => orders.where((o) => o['status'] == 'pending').length;

  /// Orders the seller has accepted and is preparing — surfaced under the
  /// "Tayyorlanmoqda" tile.
  int get processingCount => orders
      .where((o) => o['status'] == 'confirmed' || o['status'] == 'preparing')
      .length;

  /// Orders out for delivery — the "Yo'lda" tile.
  int get deliveringCount =>
      orders.where((o) => o['status'] == 'shipped').length;

  bool get hasActivity =>
      pendingCount > 0 || processingCount > 0 || deliveringCount > 0;

  ProfileOrdersState copyWith({
    List<Map<String, dynamic>>? orders,
    bool? isLoading,
  }) => ProfileOrdersState(
    orders: orders ?? this.orders,
    isLoading: isLoading ?? this.isLoading,
  );

  @override
  List<Object?> get props => [orders, isLoading];
}

class ProfileOrdersCubit extends Cubit<ProfileOrdersState> {
  ProfileOrdersCubit(this._repo, this._auth)
    : super(const ProfileOrdersState());

  final ProfileOrdersRepository _repo;
  final AuthRepository _auth;

  Future<void> fetch() async {
    if (!_auth.isAuthenticated) return;

    emit(state.copyWith(isLoading: true));

    try {
      final rows = await _repo.fetchOrders();
      emit(ProfileOrdersState(orders: rows.map(_toCardMap).toList()));
    } catch (e, st) {
      // Order-list fetch failed — clear the spinner so the UI isn't stuck,
      // and log the cause so an auth/transport failure isn't mistaken for an
      // empty list.
      talker.handle(e, st, 'ProfileOrdersCubit.load failed');
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Cancels via the backend, then patches the in-memory list so every
  /// listener (OrdersHistoryScreen, ProfileScreen badges, delete-account
  /// guard) immediately reflects the cancellation without a full re-fetch.
  Future<void> cancelOrder(String orderId, String reason) async {
    await _repo.cancel(orderId, reason);

    final updated = state.orders.map((o) {
      if (o['id'] == orderId) {
        return <String, dynamic>{
          ...o,
          'status': 'cancelled',
          'cancellation_reason': reason,
        };
      }
      return o;
    }).toList();

    emit(state.copyWith(orders: updated));
  }

  /// Maps a woody_backend `CustomerOrder` JSON row to the legacy
  /// PostgREST-shaped map the order-history UI consumes: `items`→`order_items`,
  /// `product`→`products`. `reviews` is always null because the backend has no
  /// per-item "already reviewed?" view yet — so a delivered order keeps
  /// showing the review CTA, and a re-submit is rejected with 409.
  Map<String, dynamic> _toCardMap(Map<String, dynamic> row) {
    final items = (row['items'] as List?) ?? const [];
    return {
      'id': row['id'],
      'status': row['status'],
      'total_amount': row['total_amount'],
      'created_at': row['created_at'],
      'delivery_address': row['delivery_address'],
      'cancellation_reason': row['cancellation_reason'],
      'fee_adjustment_status': row['fee_adjustment_status'],
      'proposed_delivery_fee': row['proposed_delivery_fee'],
      'order_items': [
        for (final raw in items)
          if (raw is Map<String, dynamic>)
            {
              'quantity': raw['quantity'],
              'reviews': null,
              'products': {
                'images': raw['product'] is Map<String, dynamic>
                    ? (raw['product']['images'] ?? const [])
                    : const [],
                'name': raw['product'] is Map<String, dynamic>
                    ? raw['product']['name']
                    : null,
              },
            },
      ],
    };
  }
}
