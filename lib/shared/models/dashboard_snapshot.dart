import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import 'order.dart';
import 'seller_wallet.dart';
import 'tariff.dart';

/// Debug-only backend-drift guard for the `/seller/dashboard` payload.
///
/// Every dashboard `fromJson` reads keys with null-safe defaults, so a backend
/// rename (e.g. `revenue` → `total_revenue`) degrades *silently* to 0 in
/// release. In debug we surface it: when a key the app contractually expects is
/// absent from a non-empty object, log a warning naming the offender so the
/// drift is caught during development rather than as zeroed-out charts in prod.
/// No-ops in release and on an empty object (a genuinely empty payload isn't a
/// rename). Deliberately NOT applied to [KpiDeltas] — its fields are optional
/// by contract (a `null` delta legitimately hides a trend chip), so a missing
/// key there is not drift.
void _dashboardDrift(
  Map<String, dynamic> json,
  List<String> expected,
  String model,
) {
  if (!kDebugMode || json.isEmpty) return;
  final missing = expected.where((k) => !json.containsKey(k)).toList();
  if (missing.isEmpty) return;
  appLog.warning(
    'Dashboard drift — $model is missing expected backend key(s): '
    '${missing.join(', ')}. Did the field get renamed?',
  );
}

class DailyRevenuePoint extends Equatable {
  const DailyRevenuePoint({required this.date, required this.amount});
  final DateTime date;
  final num amount;

  @override
  List<Object?> get props => [date, amount];
}

/// Last-7-days revenue series for the dashboard hero sparkline, plus the week
/// total and the week-over-week delta (`null` ⇒ no prior week to compare).
/// The backend always returns exactly 7 points, oldest→newest, zero-filled.
class WeeklySales extends Equatable {
  const WeeklySales({this.points = const [], this.total = 0, this.deltaPercent});

  final List<DailyRevenuePoint> points;
  final num total;
  final double? deltaPercent;

  factory WeeklySales.fromJson(Map<String, dynamic> json) {
    _dashboardDrift(json, const ['points', 'total'], 'WeeklySales');
    final raw = (json['points'] as List?) ?? const [];
    if (raw.isNotEmpty && raw.first is Map<String, dynamic>) {
      _dashboardDrift(
        raw.first as Map<String, dynamic>,
        const ['date', 'revenue'],
        'WeeklySales.point',
      );
    }
    return WeeklySales(
      points: raw
          .whereType<Map<String, dynamic>>()
          .map(
            (p) => DailyRevenuePoint(
              date:
                  DateTime.tryParse(p['date'] as String? ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              amount: (p['revenue'] as num?) ?? 0,
            ),
          )
          .toList(growable: false),
      total: (json['total'] as num?) ?? 0,
      deltaPercent: (json['delta_percent'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [points, total, deltaPercent];
}

/// Period-over-period % change for the KPI trend chips. A `null` field ⇒ the
/// chip hides (a metric with no meaningful historical baseline).
class KpiDeltas extends Equatable {
  const KpiDeltas({this.revenue, this.orders, this.pending, this.products});

  final double? revenue;
  final double? orders;
  final double? pending;
  final double? products;

  factory KpiDeltas.fromJson(Map<String, dynamic> json) => KpiDeltas(
    revenue: (json['revenue'] as num?)?.toDouble(),
    orders: (json['orders'] as num?)?.toDouble(),
    pending: (json['pending'] as num?)?.toDouble(),
    products: (json['products'] as num?)?.toDouble(),
  );

  @override
  List<Object?> get props => [revenue, orders, pending, products];
}

/// A milestone definition joined with the caller's live progress. Pure data —
/// the UI layer maps the `icon` token to an `IconData`. `unlocked` is sticky
/// (server-persisted), so it stays earned even if the metric later drops.
class AchievementProgress extends Equatable {
  const AchievementProgress({
    required this.code,
    required this.titleUz,
    required this.titleRu,
    this.titleEn,
    this.descriptionUz,
    this.descriptionRu,
    this.descriptionEn,
    this.rewardUz,
    this.rewardRu,
    this.rewardEn,
    required this.icon,
    required this.requirementType,
    required this.threshold,
    this.progress = 0,
    this.unlocked = false,
    this.unlockedAt,
  });

  final String code;
  final String titleUz;
  final String titleRu;
  final String? titleEn;
  final String? descriptionUz;
  final String? descriptionRu;
  final String? descriptionEn;
  // Standalone reward blurb (uz/ru/en) — the reward box copy, kept apart from
  // the short description subtitle.
  final String? rewardUz;
  final String? rewardRu;
  final String? rewardEn;
  // FontAwesome icon name (e.g. 'trophy', 'boxes-stacked'); mapped to a glyph
  // by `achievementIcon` in the UI layer.
  final String icon;
  final String requirementType;
  final num threshold;
  final num progress;
  final bool unlocked;
  final DateTime? unlockedAt;

  /// Picks [lang] (uz/ru/en) for the title, falling back uz → ru → en so a
  /// missing translation never renders blank.
  String localizedTitle(String lang) =>
      _pickLang(lang, titleUz, titleRu, titleEn);

  /// Reward blurb in [lang] with the same uz → ru → en fallback.
  String localizedReward(String lang) =>
      _pickLang(lang, rewardUz, rewardRu, rewardEn);

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    _dashboardDrift(
      json,
      const ['code', 'title_uz', 'icon', 'requirement_type', 'threshold'],
      'AchievementProgress',
    );
    return AchievementProgress(
        code: json['code'] as String? ?? '',
        titleUz: json['title_uz'] as String? ?? '',
        titleRu: json['title_ru'] as String? ?? '',
        titleEn: json['title_en'] as String?,
        descriptionUz: json['description_uz'] as String?,
        descriptionRu: json['description_ru'] as String?,
        descriptionEn: json['description_en'] as String?,
        rewardUz: json['reward_uz'] as String?,
        rewardRu: json['reward_ru'] as String?,
        rewardEn: json['reward_en'] as String?,
        icon: json['icon'] as String? ?? '',
        requirementType: json['requirement_type'] as String? ?? '',
        threshold: (json['threshold'] as num?) ?? 1,
        progress: (json['progress'] as num?) ?? 0,
        unlocked: (json['unlocked'] as bool?) ?? false,
        unlockedAt: DateTime.tryParse(json['unlocked_at'] as String? ?? ''),
      );
  }

  @override
  List<Object?> get props => [code, progress, unlocked];
}

/// Resolves a uz/ru/en triple to the requested [lang], skipping null/empty
/// values and falling back uz → ru → en.
String _pickLang(String lang, String? uz, String? ru, String? en) {
  final byLang = switch (lang) {
    'ru' => ru,
    'en' => en,
    _ => uz,
  };
  for (final candidate in [byLang, uz, ru, en]) {
    if (candidate != null && candidate.isNotEmpty) return candidate;
  }
  return '';
}

/// One row of the weekly seller ranking. Competitor names arrive masked from
/// the server; the caller's own row carries the real name + `isMe == true`.
class LeaderboardStanding extends Equatable {
  const LeaderboardStanding({
    required this.rank,
    required this.shopName,
    this.revenue = 0,
    this.deltaPercent,
    this.isMe = false,
  });

  final int rank;
  final String shopName;
  final num revenue;
  final double? deltaPercent;
  final bool isMe;

  factory LeaderboardStanding.fromJson(Map<String, dynamic> json) {
    _dashboardDrift(
      json,
      const ['rank', 'shop_name', 'revenue'],
      'LeaderboardStanding',
    );
    return LeaderboardStanding(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      shopName: json['shop_name'] as String? ?? '',
      revenue: (json['revenue'] as num?) ?? 0,
      deltaPercent: (json['delta_percent'] as num?)?.toDouble(),
      isMe: (json['is_me'] as bool?) ?? false,
    );
  }

  @override
  List<Object?> get props => [rank, shopName, revenue, isMe];
}

/// Structured weekly leaderboard from `GET /seller/leaderboard`.
class LeaderboardBoard extends Equatable {
  const LeaderboardBoard({
    required this.metric,
    required this.metricDescription,
    this.topSellers = const [],
    this.myRank,
  });

  final String metric;
  final String metricDescription;
  final List<LeaderboardStanding> topSellers;
  final LeaderboardStanding? myRank;

  factory LeaderboardBoard.fromJson(Map<String, dynamic> json) {
    return LeaderboardBoard(
      metric: json['metric'] as String? ?? 'weekly_revenue',
      metricDescription: json['metric_description'] as String? ?? '',
      topSellers: ((json['top_sellers'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LeaderboardStanding.fromJson)
          .toList(growable: false),
      myRank: json['my_rank'] is Map<String, dynamic>
          ? LeaderboardStanding.fromJson(json['my_rank'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [metric, metricDescription, topSellers, myRank];
}

/// Best-selling product over the last 30 days. `image` is a renderable URL
/// (normalised server-side) or `null`.
class TopProductStat extends Equatable {
  const TopProductStat({
    required this.productId,
    required this.name,
    this.image,
    this.unitsSold = 0,
    this.revenue = 0,
    this.deltaPercent,
  });

  final String productId;
  final String name;
  final String? image;
  final int unitsSold;
  final num revenue;
  final double? deltaPercent;

  factory TopProductStat.fromJson(Map<String, dynamic> json) {
    _dashboardDrift(
      json,
      const ['product_id', 'name', 'units_sold', 'revenue'],
      'TopProductStat',
    );
    return TopProductStat(
      productId: json['product_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      image: json['image'] as String?,
      unitsSold: (json['units_sold'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?) ?? 0,
      deltaPercent: (json['delta_percent'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [productId, unitsSold, revenue];
}

/// Numbers the dashboard shows above the fold + the rich sections (hero
/// sparkline, KPI deltas, achievements, leaderboard, top products).
class DashboardSnapshot extends Equatable {
  const DashboardSnapshot({
    required this.todaysOrders,
    required this.todaysRevenue,
    required this.pendingOrdersCount,
    required this.activeProductsCount,
    required this.tariff,
    required this.recentOrders,
    required this.last30Days,
    this.weekly = const WeeklySales(),
    this.kpiDeltas = const KpiDeltas(),
    this.achievements = const [],
    this.leaderboard = const [],
    this.topProducts = const [],
    this.wallet,
  });

  final int todaysOrders;
  final num todaysRevenue;
  final int pendingOrdersCount;
  final int activeProductsCount;
  final TariffSnapshot tariff;
  final List<Order> recentOrders;
  final List<DailyRevenuePoint> last30Days;
  final WeeklySales weekly;
  final KpiDeltas kpiDeltas;
  final List<AchievementProgress> achievements;
  final List<LeaderboardStanding> leaderboard;
  final List<TopProductStat> topProducts;

  /// Wallet/debt state — drives the dashboard's grace-warning and
  /// suspension banners. Null when the payload predates the wallet rollout.
  final SellerWallet? wallet;

  @override
  List<Object?> get props => [
        todaysOrders,
        todaysRevenue,
        pendingOrdersCount,
        activeProductsCount,
        tariff,
        recentOrders.length,
        last30Days.length,
        weekly,
        kpiDeltas,
        achievements.length,
        leaderboard.length,
        topProducts.length,
        wallet,
      ];
}
