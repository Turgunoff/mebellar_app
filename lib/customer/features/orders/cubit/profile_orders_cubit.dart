import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logging/talker.dart';

class ProfileOrdersState extends Equatable {
  const ProfileOrdersState({
    this.orders = const [],
    this.isLoading = false,
  });

  final List<Map<String, dynamic>> orders;
  final bool isLoading;

  // Derived counts — always reflect latest state without extra fields.
  int get pendingCount =>
      orders.where((o) => o['status'] == 'pending').length;
  int get processingCount => orders
      .where((o) =>
          o['status'] == 'processing' || o['status'] == 'tayyorlanmoqda')
      .length;
  int get deliveringCount => orders
      .where((o) => o['status'] == 'delivering' || o['status'] == 'yolda')
      .length;

  bool get hasActivity =>
      pendingCount > 0 || processingCount > 0 || deliveringCount > 0;

  ProfileOrdersState copyWith({
    List<Map<String, dynamic>>? orders,
    bool? isLoading,
  }) =>
      ProfileOrdersState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
      );

  @override
  List<Object?> get props => [orders, isLoading];
}

class ProfileOrdersCubit extends Cubit<ProfileOrdersState> {
  ProfileOrdersCubit(this._supabase) : super(const ProfileOrdersState());

  final SupabaseClient _supabase;

  Future<void> fetch() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    emit(state.copyWith(isLoading: true));

    try {
      final rows = await _supabase
          .from('orders')
          .select(
            'id, total_amount, status, delivery_address, created_at, '
            'cancellation_reason, fee_adjustment_status, proposed_delivery_fee',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      emit(ProfileOrdersState(
        orders: List<Map<String, dynamic>>.from(rows),
      ));
    } catch (e, st) {
      // Order-list fetch failed — clear the spinner so the UI isn't stuck,
      // and log the cause so an RLS denial isn't mistaken for an empty list.
      talker.handle(e, st, 'ProfileOrdersCubit.load failed');
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Updates Supabase, then patches the in-memory list so every listener
  /// (OrdersHistoryScreen, ProfileScreen badges, delete-account guard)
  /// immediately reflects the cancellation without a full re-fetch.
  Future<void> cancelOrder(String orderId, String reason) async {
    await _supabase.from('orders').update({
      'status': 'cancelled',
      'cancellation_reason': reason,
    }).eq('id', orderId);

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
}
