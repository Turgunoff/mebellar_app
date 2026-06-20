import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/app_mode_cubit.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/network/api_error.dart';
import '../../../../shared/models/me.dart';
import '../../../../shared/models/verification_status.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.id = '',
    this.name,
    this.phone,
    this.email,
    this.avatarUrl,
    this.isSellerPending = false,
    this.sellerVerificationStatus = VerificationStatus.none,
    this.sellerRejectionReason,
    this.rejectedBannerDismissed = false,
    this.isLoading = false,
  });

  /// Woody user id (JWT `sub`). Empty means signed out / not yet resolved.
  final String id;
  final String? name;
  final String? phone;
  final String? email;
  final String? avatarUrl;

  /// Mirrors `/me.is_seller_pending`. Drives the "Ko'rib chiqilmoqda" banner.
  final bool isSellerPending;

  /// Seller verification status from `/me.seller_profile`. Stays
  /// [VerificationStatus.none] until the backend wires the seller surface onto
  /// `/me` (Phase 4) — the approved/rejected banners light up automatically
  /// once it does.
  final VerificationStatus sellerVerificationStatus;

  /// Moderator-set rejection note, surfaced inside the rejected banner.
  final String? sellerRejectionReason;

  /// True when the user closed the rejected banner with its X — the profile
  /// then shows the regular "become a seller" CTA instead, so re-applying
  /// stays one tap away. Sourced from the server (`/me.seller_profile
  /// .rejection_alert_dismissed`) so the dismissal survives reinstall / a new
  /// device; the moderation flow re-arms it on every fresh rejection.
  final bool rejectedBannerDismissed;

  final bool isLoading;

  bool get isSignedIn => id.isNotEmpty;

  bool get hasName => name != null && name!.isNotEmpty;

  String get displayName => hasName ? name! : 'Ism kiritilmagan';

  String? get secondaryLine =>
      (phone != null && phone!.isNotEmpty) ? phone : null;

  bool get isSellerRejected => sellerVerificationStatus.isRejected;

  bool get isSellerApproved => sellerVerificationStatus.isApproved;

  ProfileState copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    bool? isSellerPending,
    VerificationStatus? sellerVerificationStatus,
    String? sellerRejectionReason,
    bool? rejectedBannerDismissed,
    bool? isLoading,
  }) {
    return ProfileState(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isSellerPending: isSellerPending ?? this.isSellerPending,
      sellerVerificationStatus:
          sellerVerificationStatus ?? this.sellerVerificationStatus,
      sellerRejectionReason:
          sellerRejectionReason ?? this.sellerRejectionReason,
      rejectedBannerDismissed:
          rejectedBannerDismissed ?? this.rejectedBannerDismissed,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    email,
    avatarUrl,
    isSellerPending,
    sellerVerificationStatus,
    sellerRejectionReason,
    rejectedBannerDismissed,
    isLoading,
  ];
}

/// Customer identity cubit, backed by the Woody `/me` endpoint.
///
/// Auth is phone-OTP based (the JWT carries `sub` + `phone`), so the header
/// seeds those two from the token for an instant paint, then `/me` fills in the
/// name, avatar and seller status. A `/me` failure is non-fatal — the seeded
/// identity stays on screen rather than blanking the card.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._auth) : super(const ProfileState(isLoading: true));

  final AuthRepository _auth;

  /// Hides the rejected banner for this user until a fresh rejection re-arms
  /// it server-side. Optimistic: flips the local flag for an instant response,
  /// then persists `rejection_alert_dismissed=true` on the seller row so the
  /// dismissal follows the account (reinstall / new device). A failed write is
  /// swallowed — the banner simply reappears on the next `/me` refresh, which
  /// is the safe degradation. The profile falls back to the "become a seller"
  /// CTA so re-applying later stays possible.
  void dismissRejectedBanner() {
    emit(state.copyWith(rejectedBannerDismissed: true));
    unawaited(
      _auth.setSellerAlertFlags(rejectionAlertDismissed: true).catchError((
        Object e,
        StackTrace st,
      ) {
        talker.handle(e, st, 'ProfileCubit.dismissRejectedBanner persist failed');
      }),
    );
  }

  Future<void> fetch() async {
    final id = _auth.currentUserId;
    if (id == null) {
      emit(const ProfileState());
      return;
    }
    // Same user refreshing → keep the loaded fields so a /me failure falls
    // back to the last-known state instead of blanking the seller banner.
    if (state.id == id) {
      emit(state.copyWith(isLoading: true));
    } else {
      emit(
        ProfileState(id: id, phone: _auth.currentUserPhone, isLoading: true),
      );
    }
    try {
      final me = await _auth.fetchMe();
      if (isClosed) return;
      emit(_fromMe(me));
      if (sl.isRegistered<AppModeCubit>()) {
        unawaited(
          sl<AppModeCubit>().recordSellerApproval(state.isSellerApproved),
        );
      }
    } on ApiError catch (e, st) {
      talker.handle(e, st, 'ProfileCubit.fetch /me failed');
      if (isClosed) return;
      emit(state.copyWith(isLoading: false));
    } catch (e, st) {
      talker.handle(e, st, 'ProfileCubit.fetch failed');
      if (isClosed) return;
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Called immediately after sign-up so the header reflects the chosen name
  /// without waiting for the next `/me` fetch.
  void applySignup({required String name, required String phone}) {
    emit(
      ProfileState(
        id: _auth.currentUserId ?? state.id,
        name: name.isEmpty ? null : name,
        phone: phone.isEmpty ? null : phone,
      ),
    );
  }

  /// Persists the editable identity fields via PATCH `/me`. Phone is the auth
  /// identity and is not mutable here. Pass [email]/[avatarUrl] only when
  /// changed — null leaves the stored value untouched (empty email would be
  /// rejected server-side, so callers normalise blanks to null).
  Future<void> updateProfile({
    required String name,
    String? email,
    String? avatarUrl,
  }) async {
    final me = await _auth.updateProfile(
      fullName: name.trim(),
      email: email,
      avatarUrl: avatarUrl,
    );
    if (isClosed) return;
    emit(_fromMe(me));
  }

  ProfileState _fromMe(Me me) {
    final seller = me.sellerProfile;
    final status = seller?.verificationStatus ?? VerificationStatus.none;
    // The dismissal only applies while the rejection is current. The backend
    // re-arms `rejection_alert_dismissed` (sets it false) on every fresh
    // rejection, so a new decision always surfaces the banner again even if an
    // earlier one was dismissed.
    final dismissed = status.isRejected && (seller?.rejectionAlertDismissed ?? false);
    return ProfileState(
      id: me.id,
      name: me.fullName,
      phone: me.phone ?? _auth.currentUserPhone,
      email: me.email,
      avatarUrl: me.avatarUrl,
      isSellerPending: me.isSellerPending,
      sellerVerificationStatus: status,
      sellerRejectionReason: seller?.rejectionReason,
      rejectedBannerDismissed: dismissed,
    );
  }
}
