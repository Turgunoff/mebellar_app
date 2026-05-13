import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_mode_cubit.dart';
import '../../../../core/auth/sign_out.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/logging/talker.dart';
import '../../../../shared/models/verification_status.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.email = '',
    this.name,
    this.phone,
    this.avatarUrl,
    this.isSellerPending = false,
    this.sellerVerificationStatus = VerificationStatus.none,
    this.sellerRejectionReason,
    this.isLoading = false,
  });

  final String email;
  final String? name;
  final String? phone;
  final String? avatarUrl;

  /// Mirrors `profiles.is_seller_pending`. Kept for the green-path
  /// "Ko'rib chiqilmoqda" banner. Stays `true` while the seller row is
  /// pending/in_review/approved; only the rejected path needs the richer
  /// status below.
  final bool isSellerPending;

  /// Source-of-truth seller status from `sellers.verification_status`. Lets
  /// the profile screen pick between the pending banner, the rejected banner,
  /// and the "become a seller" CTA without re-querying.
  final VerificationStatus sellerVerificationStatus;

  /// Set by moderators on rejection. Surfaced inside the rejected banner so
  /// the user knows what to fix before resubmitting.
  final String? sellerRejectionReason;

  final bool isLoading;

  bool get hasName => name != null && name!.isNotEmpty;

  String get displayName =>
      hasName ? name! : (email.isNotEmpty ? email : 'Ism kiritilmagan');

  String? get secondaryLine {
    if (!hasName) return null;
    return (phone != null && phone!.isNotEmpty) ? phone : email;
  }

  bool get isSellerRejected => sellerVerificationStatus.isRejected;

  bool get isSellerApproved => sellerVerificationStatus.isApproved;

  @override
  List<Object?> get props => [
    email,
    name,
    phone,
    avatarUrl,
    isSellerPending,
    sellerVerificationStatus,
    sellerRejectionReason,
    isLoading,
  ];
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
      // Fetch profile + seller in parallel. The sellers row is the source of
      // truth for verification_status / rejection_reason; profiles.is_seller_pending
      // is a denormalised flag the customer UI uses for fast banner rendering.
      final profileFuture = _supabase
          .from('profiles')
          .select('full_name, phone, avatar_url, is_seller_pending')
          .eq('id', user.id)
          .single();
      // .maybeSingle() — onboarding may not have created a sellers row yet.
      final sellerFuture = _supabase
          .from('sellers')
          .select('verification_status, rejection_reason')
          .eq('id', user.id)
          .maybeSingle();

      final results = await Future.wait<dynamic>([profileFuture, sellerFuture]);
      final data = results[0] as Map<String, dynamic>;
      final seller = results[1] as Map<String, dynamic>?;

      final next = ProfileState(
        email: user.email ?? '',
        name: data['full_name'] as String?,
        phone: data['phone'] as String?,
        avatarUrl: data['avatar_url'] as String?,
        isSellerPending: (data['is_seller_pending'] as bool?) ?? false,
        sellerVerificationStatus: VerificationStatus.fromCode(
          seller?['verification_status'] as String?,
        ),
        sellerRejectionReason: seller?['rejection_reason'] as String?,
      );
      emit(next);
      // Inform the global mode cubit so it can (a) refresh the cached
      // approval flag used by the boot-time guard and (b) demote the user
      // out of seller mode immediately if approval has been revoked
      // between launches.
      if (sl.isRegistered<AppModeCubit>()) {
        unawaited(sl<AppModeCubit>().recordSellerApproval(next.isSellerApproved));
      }
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        talker.warning(
          'Ghost session: profile row missing for ${user.id}. Forcing sign-out.',
        );
        await signOutWithPushCleanup(_supabase);
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
      sellerVerificationStatus: state.sellerVerificationStatus,
      sellerRejectionReason: state.sellerRejectionReason,
    ));
  }
}
