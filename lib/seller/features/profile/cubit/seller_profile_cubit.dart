import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/network/api_error.dart';
import '../../../../shared/models/shop_settings.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/models/verification_status.dart';
import '../../../../shared/repositories/seller_profile_repository.dart';
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
  SellerProfileCubit(this._repo, this._auth, this._cache)
    : super(const SellerProfileState(isLoading: true));

  final SellerProfileRepository _repo;
  final AuthRepository _auth;
  final SellerIdentityCache _cache;

  Future<void> load() async {
    final userId = _auth.currentUserId;
    if (userId == null) {
      emit(const SellerProfileState());
      return;
    }

    // 1. Hydrate from cache so the screen paints with last-known values
    //    immediately. Step 2 refines it — but only with fields the server
    //    actually answered for.
    final base = _cache.read(userId) ?? const SellerIdentitySnapshot();
    if (!base.isEmpty) {
      emit(SellerProfileState.fromSnapshot(base, isLoading: true));
    } else {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    // 2. Refresh from Woody. Three endpoints in parallel, each classified
    //    ok / absent (404) / failed (401, network, 5xx). A transient failure
    //    must NEVER downgrade a known-good field: a hiccup on /seller/me must
    //    not flip an approved seller back to "unverified" — nor poison the
    //    cache with that wrong value, which is what made an approved seller
    //    render as "Tasdiqlanmagan" after a stale-token boot.
    final results = await Future.wait<_Fetch>([
      _fetch(_repo.fetchMe(), label: 'me'),
      _fetch(_repo.fetchShop(), label: 'shop'),
      _fetch(_repo.fetchTariffCurrent(), label: 'tariff'),
    ]);
    final meRes = results[0];
    final shopRes = results[1];
    final tariffRes = results[2];

    // /seller/me — verification status + legal name (+ shop_name fallback).
    final verification = switch (meRes.outcome) {
      _Outcome.ok => VerificationStatus.fromCode(
          meRes.data?['verification_status'] as String?,
        ),
      _Outcome.absent => VerificationStatus.none,
      _Outcome.failed => base.verificationStatus,
    };
    final sellerName = switch (meRes.outcome) {
      _Outcome.ok => _trimOrNull(meRes.data?['legal_name'] as String?),
      _Outcome.absent => null,
      _Outcome.failed => base.sellerName,
    };
    final meShopName = meRes.outcome == _Outcome.ok
        ? _trimOrNull(meRes.data?['shop_name'] as String?)
        : null;

    // /seller/shop — shop name + logo.
    final shopName = switch (shopRes.outcome) {
      _Outcome.ok => _trimOrNull(shopRes.data?['name'] as String?) ?? meShopName,
      _Outcome.absent => meShopName,
      _Outcome.failed => meShopName ?? base.shopName,
    };
    final logoUrl = switch (shopRes.outcome) {
      _Outcome.ok => _trimOrNull(shopRes.data?['logo_url'] as String?),
      _Outcome.absent => null,
      _Outcome.failed => base.logoUrl,
    };
    final coverUrl = switch (shopRes.outcome) {
      _Outcome.ok => _trimOrNull(shopRes.data?['cover_url'] as String?),
      _Outcome.absent => null,
      _Outcome.failed => base.coverUrl,
    };

    // /seller/tariff/current — active plan.
    final plan = switch (tariffRes.outcome) {
      _Outcome.ok => TariffPlan.fromCode(tariffRes.data?['plan_code'] as String?),
      _Outcome.absent => TariffPlan.free,
      _Outcome.failed => base.plan,
    };

    final snapshot = SellerIdentitySnapshot(
      shopName: shopName,
      logoUrl: logoUrl,
      coverUrl: coverUrl,
      sellerName: sellerName,
      verificationStatus: verification,
      plan: plan,
    );

    emit(SellerProfileState.fromSnapshot(snapshot, isLoading: false));
    // Persist after emit so a slow disk write never blocks the UI render.
    unawaited(_cache.write(userId, snapshot));
  }

  /// Applies a just-saved shop-settings result straight onto the identity
  /// card — shop name, logo and cover (explicit nulls = removed) — without a
  /// refetch. The cache is rewritten too, so the next cold-start hydrate and
  /// the dashboard greeting don't resurrect a deleted image.
  void applyShopSettings(ShopSettings settings) {
    emit(
      SellerProfileState(
        isLoading: false,
        shopName: settings.name.isNotEmpty ? settings.name : state.shopName,
        logoUrl: settings.logoUrl,
        coverUrl: settings.coverUrl,
        sellerName: state.sellerName,
        verificationStatus: state.verificationStatus,
        plan: state.plan,
      ),
    );
    final userId = _auth.currentUserId;
    if (userId == null) return;
    unawaited(
      _cache.write(
        userId,
        SellerIdentitySnapshot(
          shopName: state.shopName,
          logoUrl: state.logoUrl,
          coverUrl: state.coverUrl,
          sellerName: state.sellerName,
          verificationStatus: state.verificationStatus,
          plan: state.plan,
        ),
      ),
    );
  }

  /// Classifies a single endpoint read. A 404 is a definite "no row yet"
  /// (`absent`) — distinct from a transient failure (`failed`: 401, network,
  /// 5xx) where the caller preserves the last-known value instead of blanking
  /// it. Each endpoint is independent: a missing `/seller/shop` row must not
  /// touch the verification badge, and a transient `/seller/me` failure must
  /// not touch the shop logo.
  Future<_Fetch> _fetch(
    Future<Map<String, dynamic>> future, {
    required String label,
  }) async {
    try {
      return _Fetch(_Outcome.ok, await future);
    } on ApiError catch (e, st) {
      if (e.isNotFound) return const _Fetch(_Outcome.absent);
      talker.handle(e, st, 'SellerProfileCubit.$label');
      return const _Fetch(_Outcome.failed);
    } catch (e, st) {
      talker.handle(e, st, 'SellerProfileCubit.$label');
      return const _Fetch(_Outcome.failed);
    }
  }
}

/// Outcome of a single `/seller/*` read used by [SellerProfileCubit.load].
enum _Outcome { ok, absent, failed }

class _Fetch {
  const _Fetch(this.outcome, [this.data]);

  final _Outcome outcome;
  final Map<String, dynamic>? data;
}

class SellerProfileState extends Equatable {
  const SellerProfileState({
    this.isLoading = false,
    this.shopName,
    this.logoUrl,
    this.coverUrl,
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
      coverUrl: snapshot.coverUrl,
      sellerName: snapshot.sellerName,
      verificationStatus: snapshot.verificationStatus,
      plan: snapshot.plan,
    );
  }

  final bool isLoading;
  final String? shopName;
  final String? logoUrl;
  final String? coverUrl;
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

  bool get hasCover => coverUrl != null && coverUrl!.isNotEmpty;

  /// True only when there's nothing painted yet — first cold start, no cache.
  /// Used by the identity skeleton: once cached data has been emitted we
  /// keep the previous frame on screen during background refresh instead of
  /// blanking back to a shimmer.
  bool get isInitialLoading => isLoading && shopName == null && logoUrl == null;

  SellerProfileState copyWith({
    bool? isLoading,
    String? shopName,
    String? logoUrl,
    String? coverUrl,
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
      coverUrl: coverUrl ?? this.coverUrl,
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
    coverUrl,
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
