import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/app_mode_cubit.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/services/facebook_analytics_service.dart';
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
    this.cachedIsApprovedSeller = false,
    this.sellerPromoDismissed = false,
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

  /// Last-known "is an approved seller" flag, seeded synchronously from the
  /// Hive cache ([AppModeCubit.sellerApprovedCacheKey]) at cubit construction
  /// and kept in sync with every live `/me` result. It exists purely to answer
  /// [isApprovedSellerKnown] during the loading window, before `/me` returns —
  /// the live [sellerVerificationStatus] is the source of truth once resolved.
  final bool cachedIsApprovedSeller;

  /// True once the user closed the home screen's "Sotuvchi bo'ling" promo
  /// banner with its X. Sourced from the server
  /// (`/me.seller_promo_dismissed`) so it stays dismissed across reinstall /
  /// device change; "become a seller" is still reachable from the Profile
  /// tab's CTA regardless of this flag.
  final bool sellerPromoDismissed;

  final bool isLoading;

  bool get isSignedIn => id.isNotEmpty;

  bool get hasName => name != null && name!.isNotEmpty;

  String get displayName => hasName ? name! : tr('profile.name_not_set');

  String? get secondaryLine =>
      (phone != null && phone!.isNotEmpty) ? phone : null;

  bool get isSellerRejected => sellerVerificationStatus.isRejected;

  bool get isSellerApproved => sellerVerificationStatus.isApproved;

  /// Whether the user is known to be an approved seller — from the live `/me`
  /// result, or (while that request is still in flight) from the cached flag.
  /// The customer surface reads this to hide the "become a seller" CTA on the
  /// first frame after a mode switch, so an approved seller never sees it flash
  /// during the ~1s `/me` round-trip. Once loaded, only the live status counts.
  bool get isApprovedSellerKnown =>
      isSellerApproved || (isLoading && cachedIsApprovedSeller);

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
    bool? cachedIsApprovedSeller,
    bool? sellerPromoDismissed,
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
      cachedIsApprovedSeller:
          cachedIsApprovedSeller ?? this.cachedIsApprovedSeller,
      sellerPromoDismissed: sellerPromoDismissed ?? this.sellerPromoDismissed,
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
    cachedIsApprovedSeller,
    sellerPromoDismissed,
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
  /// [cachedApprovedSeller] is read synchronously from Hive at construction
  /// (see scope_module) so the very first frame — before [fetch] resolves —
  /// already knows whether this device's last session was an approved seller.
  /// That's what stops the "become a seller" CTA flashing on the customer
  /// home/profile right after a seller→customer mode switch.
  ProfileCubit(
    this._auth, {
    bool cachedApprovedSeller = false,
    FacebookAnalyticsService? facebookAnalytics,
  }) : _facebookAnalytics = facebookAnalytics,
       super(
         ProfileState(
           isLoading: true,
           cachedIsApprovedSeller: cachedApprovedSeller,
         ),
       );

  final AuthRepository _auth;

  /// Meta conversion sink. `/me` is the one place a restored session sees the
  /// full profile, so this is where Advanced Matching gets refreshed. Optional
  /// so unit tests don't have to wire a platform-channel-backed service.
  final FacebookAnalyticsService? _facebookAnalytics;

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
        appLog.handle(
          e,
          st,
          'ProfileCubit.dismissRejectedBanner persist failed',
        );
      }),
    );
  }

  /// Hides the home screen's "Sotuvchi bo'ling" promo banner permanently.
  /// Optimistic: flips the local flag for an instant response, then persists
  /// `seller_promo_dismissed=true` via `PATCH /me` so the dismissal follows
  /// the account across reinstall / device change. A failed write is
  /// swallowed — worst case the banner reappears on the next `/me` refresh.
  /// "Become a seller" stays reachable from the Profile tab's CTA regardless.
  void dismissSellerPromo() {
    emit(state.copyWith(sellerPromoDismissed: true));
    unawaited(_persistSellerPromoDismissed());
  }

  Future<void> _persistSellerPromoDismissed() async {
    try {
      await _auth.updateProfile(sellerPromoDismissed: true);
    } catch (e, st) {
      appLog.handle(e, st, 'ProfileCubit.dismissSellerPromo persist failed');
    }
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
        ProfileState(
          id: id,
          phone: _auth.currentUserPhone,
          isLoading: true,
          // Carry the cached approval hint into the first loading frame — a
          // fresh ProfileState (new id, e.g. the post-mode-switch rebuild)
          // would otherwise reset it to false and re-introduce the flash.
          cachedIsApprovedSeller: state.cachedIsApprovedSeller,
        ),
      );
    }
    try {
      final me = await _auth.fetchMe();
      if (isClosed) return;
      emit(_fromMe(me));
      _syncAdvancedMatching(me);
      if (sl.isRegistered<AppModeCubit>()) {
        unawaited(
          sl<AppModeCubit>().recordSellerApproval(
            state.isSellerApproved,
            userId: id,
          ),
        );
      }
    } on ApiError catch (e, st) {
      appLog.handle(e, st, 'ProfileCubit.fetch /me failed');
      if (isClosed) return;
      emit(state.copyWith(isLoading: false));
    } catch (e, st) {
      appLog.handle(e, st, 'ProfileCubit.fetch failed');
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
    _syncAdvancedMatching(me);
  }

  /// Refreshes Meta's Advanced Matching payload from a freshly-resolved `/me`.
  /// Everything that decides whether anything is actually sent — the build-time
  /// flag, ATT, the in-app analytics preference — lives inside the service, so
  /// this stays an unconditional fire-and-forget on the happy path.
  void _syncAdvancedMatching(Me me) {
    final fb = _facebookAnalytics;
    if (fb == null) return;
    unawaited(
      fb.setUserProfile(
        phone: me.phone ?? _auth.currentUserPhone,
        fullName: me.fullName,
        email: me.email,
      ),
    );
  }

  ProfileState _fromMe(Me me) {
    final seller = me.sellerProfile;
    final status = seller?.verificationStatus ?? VerificationStatus.none;
    // The dismissal only applies while the rejection is current. The backend
    // re-arms `rejection_alert_dismissed` (sets it false) on every fresh
    // rejection, so a new decision always surfaces the banner again even if an
    // earlier one was dismissed.
    final dismissed =
        status.isRejected && (seller?.rejectionAlertDismissed ?? false);
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
      // Keep the cached hint mirroring live truth so a later same-user refresh
      // (which re-enters the loading window) doesn't regress to a stale value.
      cachedIsApprovedSeller: status.isApproved,
      sellerPromoDismissed: me.sellerPromoDismissed,
    );
  }
}
