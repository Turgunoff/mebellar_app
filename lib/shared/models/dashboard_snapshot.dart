import 'package:equatable/equatable.dart';

import 'order.dart';
import 'tariff.dart';

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
    final raw = (json['points'] as List?) ?? const [];
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
    this.descriptionUz,
    this.descriptionRu,
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
  final String? descriptionUz;
  final String? descriptionRu;
  final String icon;
  final String requirementType;
  final num threshold;
  final num progress;
  final bool unlocked;
  final DateTime? unlockedAt;

  factory AchievementProgress.fromJson(Map<String, dynamic> json) =>
      AchievementProgress(
        code: json['code'] as String? ?? '',
        titleUz: json['title_uz'] as String? ?? '',
        titleRu: json['title_ru'] as String? ?? '',
        descriptionUz: json['description_uz'] as String?,
        descriptionRu: json['description_ru'] as String?,
        icon: json['icon'] as String? ?? '',
        requirementType: json['requirement_type'] as String? ?? '',
        threshold: (json['threshold'] as num?) ?? 1,
        progress: (json['progress'] as num?) ?? 0,
        unlocked: (json['unlocked'] as bool?) ?? false,
        unlockedAt: DateTime.tryParse(json['unlocked_at'] as String? ?? ''),
      );

  @override
  List<Object?> get props => [code, progress, unlocked];
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

  factory LeaderboardStanding.fromJson(Map<String, dynamic> json) =>
      LeaderboardStanding(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        shopName: json['shop_name'] as String? ?? '',
        revenue: (json['revenue'] as num?) ?? 0,
        deltaPercent: (json['delta_percent'] as num?)?.toDouble(),
        isMe: (json['is_me'] as bool?) ?? false,
      );

  @override
  List<Object?> get props => [rank, shopName, revenue, isMe];
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

  factory TopProductStat.fromJson(Map<String, dynamic> json) => TopProductStat(
    productId: json['product_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    image: json['image'] as String?,
    unitsSold: (json['units_sold'] as num?)?.toInt() ?? 0,
    revenue: (json['revenue'] as num?) ?? 0,
    deltaPercent: (json['delta_percent'] as num?)?.toDouble(),
  );

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
      ];
}
