import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logging/talker.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.email = '',
    this.name,
    this.phone,
    this.avatarUrl,
    this.isSellerPending = false,
    this.isLoading = false,
  });

  final String email;
  final String? name;
  final String? phone;
  final String? avatarUrl;
  final bool isSellerPending;
  final bool isLoading;

  bool get hasName => name != null && name!.isNotEmpty;

  String get displayName =>
      hasName ? name! : (email.isNotEmpty ? email : 'Ism kiritilmagan');

  String? get secondaryLine {
    if (!hasName) return null;
    return (phone != null && phone!.isNotEmpty) ? phone : email;
  }

  @override
  List<Object?> get props =>
      [email, name, phone, avatarUrl, isSellerPending, isLoading];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._supabase) : super(const ProfileState(isLoading: true));

  final SupabaseClient _supabase;

  Future<void> fetch() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      emit(const ProfileState());
      return;
    }
    emit(ProfileState(email: user.email ?? '', isLoading: true));
    try {
      final data = await _supabase
          .from('profiles')
          .select('full_name, phone, avatar_url, is_seller_pending')
          .eq('id', user.id)
          .single();
      emit(ProfileState(
        email: user.email ?? '',
        name: data['full_name'] as String?,
        phone: data['phone'] as String?,
        avatarUrl: data['avatar_url'] as String?,
        isSellerPending: (data['is_seller_pending'] as bool?) ?? false,
      ));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        talker.warning(
          'Ghost session: profile row missing for ${user.id}. Forcing sign-out.',
        );
        await _supabase.auth.signOut();
      }
      emit(ProfileState(email: user.email ?? ''));
    } catch (_) {
      emit(ProfileState(email: user.email ?? ''));
    }
  }

  /// Called immediately after sign-up upsert completes, before Navigator.pop.
  /// Eliminates the race condition where `userUpdated` fires before the
  /// `profiles` row commits, causing a stale fetch.
  void applySignup({
    required String name,
    required String phone,
    required String email,
  }) {
    emit(ProfileState(
      email: email,
      name: name.isEmpty ? null : name,
      phone: phone.isEmpty ? null : phone,
    ));
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final trimName = name.trim();
    final trimPhone = phone.trim();
    await _supabase.from('profiles').update({
      'full_name': trimName,
      'phone': trimPhone,
    }).eq('id', user.id);
    emit(ProfileState(
      email: state.email,
      name: trimName.isEmpty ? null : trimName,
      phone: trimPhone.isEmpty ? null : trimPhone,
      avatarUrl: state.avatarUrl,
      isSellerPending: state.isSellerPending,
    ));
  }
}
