import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/logging/talker.dart';
import '../../../../shared/models/tariff.dart';
import '../../../../shared/models/verification_status.dart';

/// Local snapshot of the seller-identity fields displayed across the seller
/// surfaces (dashboard greeting + profile header).
///
/// Stored in `HiveBoxes.cache` and wiped by `performLogout`, so the cache
/// never bleeds across users. Keyed by `auth.uid()` defensively — a stale
/// row from a previous user never renders even if the logout teardown was
/// interrupted (e.g. app killed mid-clear).
class SellerIdentitySnapshot {
  const SellerIdentitySnapshot({
    this.shopName,
    this.logoUrl,
    this.sellerName,
    this.verificationStatus = VerificationStatus.none,
    this.plan = TariffPlan.free,
  });

  final String? shopName;
  final String? logoUrl;
  final String? sellerName;
  final VerificationStatus verificationStatus;
  final TariffPlan plan;

  bool get isEmpty =>
      shopName == null &&
      logoUrl == null &&
      sellerName == null &&
      verificationStatus == VerificationStatus.none &&
      plan == TariffPlan.free;

  Map<String, dynamic> toJson() => {
        'shop_name': shopName,
        'logo_url': logoUrl,
        'seller_name': sellerName,
        'verification_status': verificationStatus.code,
        'plan_code': plan.code,
      };

  factory SellerIdentitySnapshot.fromJson(Map<dynamic, dynamic> json) {
    return SellerIdentitySnapshot(
      shopName: json['shop_name'] as String?,
      logoUrl: json['logo_url'] as String?,
      sellerName: json['seller_name'] as String?,
      verificationStatus:
          VerificationStatus.fromCode(json['verification_status'] as String?),
      plan: TariffPlan.fromCode(json['plan_code'] as String?),
    );
  }

  SellerIdentitySnapshot copyWith({
    String? shopName,
    String? logoUrl,
    String? sellerName,
    VerificationStatus? verificationStatus,
    TariffPlan? plan,
  }) {
    return SellerIdentitySnapshot(
      shopName: shopName ?? this.shopName,
      logoUrl: logoUrl ?? this.logoUrl,
      sellerName: sellerName ?? this.sellerName,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      plan: plan ?? this.plan,
    );
  }
}

/// Hive-backed cache for [SellerIdentitySnapshot]. Both the profile screen
/// and the dashboard greeting hydrate from this on cold start, then refresh
/// in the background — the user sees their shop name/avatar at 0 ms instead
/// of waiting for Supabase RTTs.
///
/// Writes are partial-friendly: a caller that only knows the greeting
/// fields (dashboard) merges into the existing snapshot rather than wiping
/// the profile-only fields the other surface fetched. This is what lets two
/// independent cubits share one cache row without stomping each other.
class SellerIdentityCache {
  SellerIdentityCache(this._box);

  static const String _keyPrefix = 'seller_identity_';

  final Box _box;

  String _key(String userId) => '$_keyPrefix$userId';

  SellerIdentitySnapshot? read(String userId) {
    try {
      final raw = _box.get(_key(userId));
      if (raw is! Map) return null;
      return SellerIdentitySnapshot.fromJson(raw);
    } catch (e, st) {
      talker.handle(e, st, 'SellerIdentityCache.read');
      return null;
    }
  }

  Future<void> write(String userId, SellerIdentitySnapshot snapshot) async {
    try {
      await _box.put(_key(userId), snapshot.toJson());
    } catch (e, st) {
      talker.handle(e, st, 'SellerIdentityCache.write');
    }
  }

  /// Merges [patch] into the existing row (or seeds a new one). Used by the
  /// dashboard greeting fetch, which only knows `shopName`/`sellerName` —
  /// the profile-only fields (logo, verification, plan) must survive.
  Future<void> merge(String userId, SellerIdentitySnapshot patch) async {
    final existing = read(userId) ?? const SellerIdentitySnapshot();
    final merged = existing.copyWith(
      shopName: patch.shopName ?? existing.shopName,
      logoUrl: patch.logoUrl ?? existing.logoUrl,
      sellerName: patch.sellerName ?? existing.sellerName,
      verificationStatus:
          patch.verificationStatus == VerificationStatus.none
              ? existing.verificationStatus
              : patch.verificationStatus,
      plan: patch.plan == TariffPlan.free && existing.plan != TariffPlan.free
          ? existing.plan
          : patch.plan,
    );
    await write(userId, merged);
  }
}
