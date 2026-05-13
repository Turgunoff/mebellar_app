import 'package:equatable/equatable.dart';

/// Tariff catalog. Mirrors `public.subscription_plans` — keep enum values in
/// lockstep with the row backing each `code`. `-1` everywhere = unlimited.
/// Yearly price is ~10x monthly (≈17% off) per the spec.
enum TariffPlan {
  free(
    'free',
    maxActiveProducts: 3,
    maxImagesPerProduct: 2,
    commissionRate: 10.0,
    monthlyPriceUzs: 0,
    yearlyPriceUzs: 0,
  ),
  basic(
    'basic',
    maxActiveProducts: 30,
    maxImagesPerProduct: 5,
    commissionRate: 7.0,
    monthlyPriceUzs: 99_000,
    yearlyPriceUzs: 990_000,
  ),
  pro(
    'pro',
    maxActiveProducts: 200,
    maxImagesPerProduct: 10,
    commissionRate: 4.0,
    monthlyPriceUzs: 299_000,
    yearlyPriceUzs: 2_990_000,
    recommended: true,
  ),
  enterprise(
    'enterprise',
    maxActiveProducts: -1,
    maxImagesPerProduct: -1,
    commissionRate: 2.0,
    monthlyPriceUzs: 999_000,
    yearlyPriceUzs: 9_990_000,
  );

  const TariffPlan(
    this.code, {
    required this.maxActiveProducts,
    required this.maxImagesPerProduct,
    required this.commissionRate,
    required this.monthlyPriceUzs,
    required this.yearlyPriceUzs,
    this.recommended = false,
  });

  final String code;

  /// `-1` means unlimited. UI renders that as the infinity sign.
  final int maxActiveProducts;

  /// `-1` means unlimited.
  final int maxImagesPerProduct;

  /// Percentage taken from each completed sale (e.g. `10.0` for 10%).
  final double commissionRate;

  final int monthlyPriceUzs;
  final int yearlyPriceUzs;
  final bool recommended;

  static TariffPlan fromCode(String? code) {
    return values.firstWhere(
      (t) => t.code == code,
      orElse: () => TariffPlan.free,
    );
  }

  bool get isUnlimited => maxActiveProducts < 0;
  bool get hasUnlimitedImages => maxImagesPerProduct < 0;
  bool get isFree => this == TariffPlan.free;

  /// Gate used by the "Add product" flow.
  bool canAddMoreProducts(int currentCount) =>
      isUnlimited || currentCount < maxActiveProducts;

  /// Gate used by the image-picker step.
  bool canAddMoreImages(int currentImageCount) =>
      hasUnlimitedImages || currentImageCount < maxImagesPerProduct;

  int priceFor(BillingPeriod period) {
    return switch (period) {
      BillingPeriod.monthly => monthlyPriceUzs,
      BillingPeriod.yearly => yearlyPriceUzs,
    };
  }
}

/// Row of `public.subscription_plans`. The hard-coded [TariffPlan] enum stays
/// the source of truth for compile-time references (UI cards, mock seeds),
/// but [SubscriptionPlan] is what the backend returns and is used wherever
/// the limit must be verified against live data (add-product gate, image
/// upload gate). Both shapes are aligned via `code`.
class SubscriptionPlan extends Equatable {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.priceMonthly,
    required this.maxProducts,
    required this.maxImagesPerProduct,
    required this.commissionRate,
    this.isRecommended = false,
    this.featuresUz = const [],
    this.featuresRu = const [],
  });

  final String id;
  final String code;
  final String name;
  final num priceMonthly;

  /// `-1` means unlimited.
  final int maxProducts;

  /// `-1` means unlimited.
  final int maxImagesPerProduct;

  /// Percentage (e.g. `10.0` for 10%).
  final num commissionRate;

  /// Drives the "TAVSIYA" ribbon on the tariff cards. Server-controlled so
  /// the merchandising decision (which plan to push) can change without an
  /// app release.
  final bool isRecommended;

  /// Locale-keyed feature bullets straight from `subscription_plans.features_*`.
  /// The UI calls [featuresForLocale] which picks the right list.
  final List<String> featuresUz;
  final List<String> featuresRu;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      priceMonthly: (json['price_monthly'] as num?) ?? 0,
      maxProducts: (json['max_products'] as num?)?.toInt() ?? 0,
      maxImagesPerProduct:
          (json['max_images_per_product'] as num?)?.toInt() ?? 0,
      commissionRate: (json['commission_rate'] as num?) ?? 0,
      isRecommended: json['is_recommended'] as bool? ?? false,
      featuresUz: _stringList(json['features_uz']),
      featuresRu: _stringList(json['features_ru']),
    );
  }

  /// JSONB columns arrive as `List<dynamic>` from supabase-flutter (already
  /// decoded). Be defensive against null and non-string entries.
  static List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  bool get hasUnlimitedProducts => maxProducts < 0;
  bool get hasUnlimitedImages => maxImagesPerProduct < 0;
  bool get isFree => priceMonthly == 0;

  /// Resolves a price for the given billing period. The DB currently only
  /// stores `price_monthly`; until `price_yearly` is added, yearly is
  /// derived as `monthly × 10` (the standard ~17% annual discount). Add a
  /// `price_yearly` column and read it here when business wants different.
  num priceFor(BillingPeriod period) {
    return switch (period) {
      BillingPeriod.monthly => priceMonthly,
      BillingPeriod.yearly => priceMonthly * 10,
    };
  }

  /// Single source of truth for the add-product gate. Mirrors the DB-level
  /// trigger on `products` INSERT.
  bool canAddMoreProducts(int currentCount) =>
      hasUnlimitedProducts || currentCount < maxProducts;

  bool canAddMoreImages(int currentImageCount) =>
      hasUnlimitedImages || currentImageCount < maxImagesPerProduct;

  /// Returns the feature bullets for [languageCode] (`'uz'` / `'ru'` /
  /// `'en'`). English falls back to the Uzbek list because the DB doesn't
  /// store English yet — when we add `features_en`, wire it here.
  List<String> featuresForLocale(String languageCode) {
    return switch (languageCode) {
      'ru' => featuresRu,
      _ => featuresUz,
    };
  }

  /// Bridges to the enum so callers that already speak [TariffPlan] (mock
  /// repos, the dashboard KPI tile) keep working.
  TariffPlan get asEnum => TariffPlan.fromCode(code);

  @override
  List<Object?> get props => [
        id,
        code,
        priceMonthly,
        maxProducts,
        maxImagesPerProduct,
        commissionRate,
        isRecommended,
        featuresUz,
        featuresRu,
      ];
}

enum BillingPeriod {
  monthly('monthly'),
  yearly('yearly');

  const BillingPeriod(this.code);
  final String code;
}

/// Backend would return more — this is enough for the dashboard KPI tile
/// and the create-product limit guard.
class TariffSnapshot extends Equatable {
  const TariffSnapshot({
    required this.plan,
    required this.activeProductsCount,
  });

  final TariffPlan plan;
  final int activeProductsCount;

  bool get reachedLimit =>
      !plan.isUnlimited && activeProductsCount >= plan.maxActiveProducts;

  bool get canAddMoreProducts => plan.canAddMoreProducts(activeProductsCount);

  @override
  List<Object?> get props => [plan, activeProductsCount];
}

class TariffLimitException implements Exception {
  TariffLimitException(this.snapshot);
  final TariffSnapshot snapshot;

  @override
  String toString() => 'TariffLimitException(${snapshot.plan.code})';
}

enum TariffUpgradeStatus {
  none('none'),
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  cancelled('cancelled');

  const TariffUpgradeStatus(this.code);
  final String code;

  static TariffUpgradeStatus fromCode(String? code) {
    return values.firstWhere(
      (s) => s.code == code,
      orElse: () => TariffUpgradeStatus.none,
    );
  }

  bool get isPending => this == TariffUpgradeStatus.pending;
  bool get isApproved => this == TariffUpgradeStatus.approved;
  bool get isRejected => this == TariffUpgradeStatus.rejected;
  bool get isTerminal =>
      this == TariffUpgradeStatus.approved ||
      this == TariffUpgradeStatus.rejected ||
      this == TariffUpgradeStatus.cancelled;
}

/// One row in the seller's payment history. Mock seeds an `approved` past
/// upgrade and the active `pending` request after submission.
class TariffSubscription extends Equatable {
  const TariffSubscription({
    required this.id,
    required this.plan,
    required this.period,
    required this.amount,
    required this.status,
    required this.submittedAt,
    this.approvedAt,
    this.rejectedAt,
    this.expiresAt,
    this.rejectionReason,
    this.paymentScreenshotUrl,
  });

  final String id;
  final TariffPlan plan;
  final BillingPeriod period;
  final int amount;
  final TariffUpgradeStatus status;
  final DateTime submittedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? expiresAt;
  final String? rejectionReason;
  final String? paymentScreenshotUrl;

  TariffSubscription copyWith({
    TariffUpgradeStatus? status,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    DateTime? expiresAt,
    String? rejectionReason,
  }) {
    return TariffSubscription(
      id: id,
      plan: plan,
      period: period,
      amount: amount,
      status: status ?? this.status,
      submittedAt: submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      paymentScreenshotUrl: paymentScreenshotUrl,
    );
  }

  /// 24-hour SLA per spec — the pending screen counts down from this.
  Duration get slaRemaining {
    if (!status.isPending) return Duration.zero;
    final due = submittedAt.add(const Duration(hours: 24));
    final left = due.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  List<Object?> get props =>
      [id, plan, period, amount, status, submittedAt, approvedAt, rejectedAt];
}
