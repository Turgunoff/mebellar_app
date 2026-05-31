import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/network/woody_api_client.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/models/verification_status.dart';
import '../data/seller_identity_cache.dart';

/// Single-state cubit powering [SellerProfileScreen].
///
/// Stale-while-revalidate: on `load()` we read the cached
/// [SellerIdentitySnapshot] from Hive and emit it immediately (0 ms render),
/// then fan out three parallel Woody reads in the background:
///   * `GET /seller/me`             — legal_name + verification_status (+ shop_name).
///   * `GET /seller/shop`           — logo_url + name for the identity card.
///   * `GET /seller/tariff/current` — the active plan code for the "Joriy tarif"
///                                    subtitle on the Tariff row.
/// Whatever comes back replaces the cache and re-emits a fresh state. Each read
/// is swallowed individually so a brand-new seller (no shop yet — 404 on
/// `/seller/me` and `/seller/shop`, free plan) lands on the zero-state values
/// (`Sotuvchi`, no logo, `VerificationStatus.none`, `TariffPlan.free`) instead
/// of an exception.
class SellerProfileCubit extends Cubit<SellerProfileState> {
  SellerProfileCubit(this._api, this._auth, this._cache)
    : super(const SellerProfileState(isLoading: true));

  final WoodyApiClient _api;
  final AuthRepository _auth;
  final SellerIdentityCache _cache;

  Future<void> load() async {
    final userId = _auth.currentUserId;
    if (userId == null) {
      emit(const SellerProfileState());
      return;
    }

    // 1. Hydrate from cache so the screen paints with last-known values
    //    immediately. The fresh fetch overrides whatever was here in step 2.
    final cached = _cache.read(userId);
    if (cached != null && !cached.isEmpty) {
      emit(SellerProfileState.fromSnapshot(cached, isLoading: true));
    } else {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    // 2. Refresh from Woody. Three endpoints fetched in parallel.
    try {
      final results = await Future.wait<Map<String, dynamic>?>([
        _swallow(_api.get<Map<String, dynamic>>('/seller/me'), label: 'me'),
        _swallow(_api.get<Map<String, dynamic>>('/seller/shop'), label: 'shop'),
        _swallow(
          _api.get<Map<String, dynamic>>('/seller/tariff/current'),
          label: 'tariff',
        ),
      ]);
      final me = results[0];
      final shop = results[1];
      final tariff = results[2];

      final snapshot = SellerIdentitySnapshot(
        shopName: _trimOrNull(
          (shop?['name'] as String?) ?? (me?['shop_name'] as String?),
        ),
        logoUrl: _trimOrNull(shop?['logo_url'] as String?),
        sellerName: _trimOrNull(me?['legal_name'] as String?),
        verificationStatus: VerificationStatus.fromCode(
          me?['verification_status'] as String?,
        ),
        plan: TariffPlan.fromCode(tariff?['plan_code'] as String?),
      );

      emit(SellerProfileState.fromSnapshot(snapshot, isLoading: false));
      // Persist after emit so a slow disk write never blocks the UI render.
      unawaited(_cache.write(userId, snapshot));
    } catch (e, st) {
      // Unreachable in practice — each read is already swallowed individually
      // — but surfacing the error here keeps the screen renderable on a truly
      // unexpected failure (e.g. Future.wait itself).
      talker.handle(e, st, 'SellerProfileCubit.load');
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Each endpoint is independent: a missing `/seller/me` row (pre-onboarding)
  /// must not blank out the shop logo, and a free plan (404 on tariff) must not
  /// blank out the verification badge.
  Future<Map<String, dynamic>?> _swallow(
    Future<Map<String, dynamic>> future, {
    required String label,
  }) async {
    try {
      return await future;
    } catch (e, st) {
      talker.handle(e, st, 'SellerProfileCubit.$label');
      return null;
    }
  }
}

class SellerProfileState extends Equatable {
  const SellerProfileState({
    this.isLoading = false,
    this.shopName,
    this.logoUrl,
    this.sellerName,
    this.verificationStatus = VerificationStatus.none,
    this.plan = TariffPlan.free,
    this.error,
  });

  factory SellerProfileState.fromSnapshot(
    SellerIdentitySnapshot snapshot, {
    required bool isLoading,
  }) {
    return SellerProfileState(
      isLoading: isLoading,
      shopName: snapshot.shopName,
      logoUrl: snapshot.logoUrl,
      sellerName: snapshot.sellerName,
      verificationStatus: snapshot.verificationStatus,
      plan: snapshot.plan,
    );
  }

  final bool isLoading;
  final String? shopName;
  final String? logoUrl;
  final String? sellerName;
  final VerificationStatus verificationStatus;
  final TariffPlan plan;
  final String? error;

  /// Fallback chain: shop name → seller's legal name → generic.
  String get displayShopName {
    if (shopName != null && shopName!.isNotEmpty) return shopName!;
    if (sellerName != null && sellerName!.isNotEmpty) return sellerName!;
    return 'Sotuvchi';
  }

  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;

  /// True only when there's nothing painted yet — first cold start, no cache.
  /// Used by the identity skeleton: once cached data has been emitted we
  /// keep the previous frame on screen during background refresh instead of
  /// blanking back to a shimmer.
  bool get isInitialLoading => isLoading && shopName == null && logoUrl == null;

  SellerProfileState copyWith({
    bool? isLoading,
    String? shopName,
    String? logoUrl,
    String? sellerName,
    VerificationStatus? verificationStatus,
    TariffPlan? plan,
    String? error,
    bool clearError = false,
  }) {
    return SellerProfileState(
      isLoading: isLoading ?? this.isLoading,
      shopName: shopName ?? this.shopName,
      logoUrl: logoUrl ?? this.logoUrl,
      sellerName: sellerName ?? this.sellerName,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      plan: plan ?? this.plan,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    shopName,
    logoUrl,
    sellerName,
    verificationStatus,
    plan,
    error,
  ];
}

String? _trimOrNull(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}
