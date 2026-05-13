import 'package:equatable/equatable.dart';

import 'multilingual_text.dart';
import 'tariff.dart';

class Shop extends Equatable {
  const Shop({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.contactPhone,
    this.telegramUsername,
    this.isVerified = false,
    this.brandColor,
    this.planId,
    this.plan,
  });

  final String id;
  final String slug;
  final MultilingualText name;
  final MultilingualText? description;
  final String? logoUrl;
  final String? coverUrl;
  final String? contactPhone;
  final String? telegramUsername;
  final bool isVerified;
  final String? brandColor;

  /// FK to `subscription_plans.id`. Null only for shops created before the
  /// Sprint 10 migration backfilled the default 'free' plan.
  final String? planId;

  /// Nested plan row when the query did a `select(..., plan:subscription_plans(*))`.
  /// Use [planOrFree] for a non-null value with a safe fallback.
  final SubscriptionPlan? plan;

  /// Convenience that returns the actual plan or, if not loaded / not yet
  /// migrated, the free-tier defaults derived from the enum so callers can
  /// gate without null checks.
  SubscriptionPlan get planOrFree =>
      plan ??
      SubscriptionPlan(
        id: '',
        code: TariffPlan.free.code,
        name: TariffPlan.free.code,
        priceMonthly: TariffPlan.free.monthlyPriceUzs,
        maxProducts: TariffPlan.free.maxActiveProducts,
        maxImagesPerProduct: TariffPlan.free.maxImagesPerProduct,
        commissionRate: TariffPlan.free.commissionRate,
      );

  /// Gate used by the "Add product" flow — delegates to the active plan.
  bool canAddMoreProducts(int currentCount) =>
      planOrFree.canAddMoreProducts(currentCount);

  bool canAddMoreImages(int currentImageCount) =>
      planOrFree.canAddMoreImages(currentImageCount);

  factory Shop.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'];
    return Shop(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? json['id'] as String,
      name: MultilingualText.fromJson(json['name'] as Map<String, dynamic>?),
      description: MultilingualText.fromJson(
        json['description'] as Map<String, dynamic>?,
      ),
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      contactPhone: json['contact_phone'] as String?,
      telegramUsername: json['telegram_username'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      brandColor: json['brand_color'] as String?,
      planId: json['plan_id'] as String?,
      plan: planJson is Map<String, dynamic>
          ? SubscriptionPlan.fromJson(planJson)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, slug, isVerified, planId];
}
