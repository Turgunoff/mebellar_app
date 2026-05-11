import 'package:equatable/equatable.dart';

/// Tariff catalog. Sprint 7 introduced the basic shape (limit + monthly
/// price) so the dashboard's product KPI could surface a tariff hit. Sprint 9
/// fleshes it out with yearly pricing (12-month plan with ~17% discount) and
/// a `recommended` flag for the upgrade UX.
enum TariffPlan {
  free(
    'free',
    maxActiveProducts: 5,
    monthlyPriceUzs: 0,
    yearlyPriceUzs: 0,
  ),
  basic(
    'basic',
    maxActiveProducts: 50,
    monthlyPriceUzs: 99_000,
    yearlyPriceUzs: 990_000,
  ),
  pro(
    'pro',
    maxActiveProducts: 500,
    monthlyPriceUzs: 299_000,
    yearlyPriceUzs: 2_990_000,
    recommended: true,
  ),
  enterprise(
    'enterprise',
    maxActiveProducts: -1,
    monthlyPriceUzs: 999_000,
    yearlyPriceUzs: 9_990_000,
  );

  const TariffPlan(
    this.code, {
    required this.maxActiveProducts,
    required this.monthlyPriceUzs,
    required this.yearlyPriceUzs,
    this.recommended = false,
  });

  final String code;

  /// `-1` means unlimited. UI renders that as the infinity sign.
  final int maxActiveProducts;
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
  bool get isFree => this == TariffPlan.free;

  int priceFor(BillingPeriod period) {
    return switch (period) {
      BillingPeriod.monthly => monthlyPriceUzs,
      BillingPeriod.yearly => yearlyPriceUzs,
    };
  }
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
