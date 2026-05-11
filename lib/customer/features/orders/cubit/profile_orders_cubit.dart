import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileOrdersState extends Equatable {
  const ProfileOrdersState({
    this.pendingCount = 0,
    this.processingCount = 0,
    this.deliveringCount = 0,
    this.isLoading = false,
  });

  final int pendingCount;
  final int processingCount;
  final int deliveringCount;
  final bool isLoading;

  bool get hasActivity =>
      pendingCount > 0 || processingCount > 0 || deliveringCount > 0;

  @override
  List<Object?> get props =>
      [pendingCount, processingCount, deliveringCount, isLoading];
}

class ProfileOrdersCubit extends Cubit<ProfileOrdersState> {
  ProfileOrdersCubit(this._supabase) : super(const ProfileOrdersState());

  final SupabaseClient _supabase;

  Future<void> fetch() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    emit(const ProfileOrdersState(isLoading: true));

    try {
      final rows = await _supabase
          .from('orders')
          .select('status')
          .eq('user_id', userId);

      int pending = 0, processing = 0, delivering = 0;
      for (final row in rows) {
        switch (row['status'] as String? ?? '') {
          case 'pending':
            pending++;
          case 'processing':
          case 'tayyorlanmoqda':
            processing++;
          case 'delivering':
          case 'yolda':
            delivering++;
        }
      }

      emit(ProfileOrdersState(
        pendingCount: pending,
        processingCount: processing,
        deliveringCount: delivering,
      ));
    } catch (_) {
      emit(const ProfileOrdersState());
    }
  }
}
