import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logging/talker.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/models/verification_status.dart';
import '../data/seller_identity_cache.dart';

/// Single-state cubit powering [SellerProfileScreen].
///
/// Stale-while-revalidate: on `load()` we read the cached
/// [SellerIdentitySnapshot] from Hive and emit it immediately (0 ms render),
/// then fan out three parallel Supabase reads in the background:
///   * `shops`         — name + logo for the identity card.
///   * `sellers`       — `verification_status` for the badge under the name.
///   * `subscriptions` — the approved plan code for the "Joriy tarif" subtitle
///                       on the Tariff row.
/// Whatever comes back replaces the cache and re-emits a fresh state. Every
/// read is wrapped so a brand-new seller (no shop yet, no approved
/// subscription) lands on the zero-state values (`Sotuvchi`, no logo,
/// `VerificationStatus.none`, `TariffPlan.free`) instead of an exception.
class SellerProfileCubit extends Cubit<SellerProfileState> {
  SellerProfileCubit(this._client, this._cache)
      : super(const SellerProfileState(isLoading: true));

  final SupabaseClient _client;
  final SellerIdentityCache _cache;

  Future<void> load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      emit(const SellerProfileState());
      return;
    }

    // 1. Hydrate from cache so the screen paints with last-known values
    //    immediately. The fresh fetch overrides whatever was here in step 2.
    final cached = _cache.read(user.id);
    if (cached != null && !cached.isEmpty) {
      emit(SellerProfileState.fromSnapshot(cached, isLoading: true));
    } else {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    // 2. Refresh from Supabase. Three rows fetched in parallel.
    try {
      final shopFuture = _client
          .from('shops')
          .select('name, logo_url')
          .eq('seller_id', user.id)
          .maybeSingle();
      final sellerFuture = _client
          .from('sellers')
          .select('legal_name, verification_status')
          .eq('id', user.id)
          .maybeSingle();
      final subscriptionFuture = _client
          .from('subscriptions')
          .select('plan_code')
          .eq('seller_id', user.id)
          .eq('status', 'approved')
          .order('expires_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final results = await Future.wait<Map<String, dynamic>?>([
        _swallow(shopFuture, label: 'shops'),
        _swallow(sellerFuture, label: 'sellers'),
        _swallow(subscriptionFuture, label: 'subscriptions'),
      ]);
      final shop = results[0];
      final seller = results[1];
      final subscription = results[2];

      final snapshot = SellerIdentitySnapshot(
        shopName: _trimOrNull(shop?['name'] as String?),
        logoUrl: _trimOrNull(shop?['logo_url'] as String?),
        sellerName: _trimOrNull(seller?['legal_name'] as String?),
        verificationStatus: VerificationStatus.fromCode(
          seller?['verification_status'] as String?,
        ),
        plan: TariffPlan.fromCode(subscription?['plan_code'] as String?),
      );

      emit(SellerProfileState.fromSnapshot(snapshot, isLoading: false));
      // Persist after emit so a slow disk write never blocks the UI render.
      unawaited(_cache.write(user.id, snapshot));
    } catch (e, st) {
      // Unreachable in practice — each row read is already swallowed
      // individually — but surfacing the error here keeps the screen
      // renderable on a truly unexpected failure (e.g. Future.wait itself).
      talker.handle(e, st, 'SellerProfileCubit.load');
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Each row is independent: a missing `sellers` row (pre-onboarding) must
  /// not blank out the shop name, and a missing `subscriptions` row (no
  /// upgrade yet) must not blank out the verification badge.
  Future<Map<String, dynamic>?> _swallow(
    Future<Map<String, dynamic>?> future, {
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
