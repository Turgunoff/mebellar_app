import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Mock data feeding the *rich* sections of the seller dashboard — the hero
/// sparkline, KPI deltas, the seller leaderboard, the achievements strip and
/// the top-products card.
///
/// These are intentionally NOT wired to a repository yet: the UI is being
/// designed first against realistic fake data, then the backend will replace
/// each `mock*` getter with a live `/seller/dashboard/*` payload.
///
/// When the backend lands:
///   * `mockRevenueSeries`  → `GET /seller/dashboard/revenue?range=7d`
///   * `mockSalesDelta`     → period-over-period delta from the same endpoint
///   * `mockKpiDeltas`      → already returned alongside today's KPIs
///   * `mockLeaderboard`    → `GET /seller/dashboard/leaderboard?period=week`
///   * `mockAchievements`   → `GET /seller/dashboard/achievements`
///   * `mockTopProducts`    → `GET /seller/dashboard/top-products?range=30d`
///
/// Everything here is deterministic (no `Random`, no `DateTime.now()` inside
/// const data) so the screen renders identically across hot reloads and so a
/// future golden test stays stable.
class DashboardMock {
  const DashboardMock._();

  // ---- Hero sales card ----------------------------------------------------

  /// Last-7-days revenue, oldest → newest. Drives the hero sparkline and the
  /// big "Bu hafta savdo" number (the sum). Realistic furniture-shop swing:
  /// a slow start, a mid-week dip, a strong weekend.
  static const List<double> mockRevenueSeries = [
    3_200_000,
    4_750_000,
    4_100_000,
    6_900_000,
    5_400_000,
    8_300_000,
    9_650_000,
  ];

  /// Weekday initials under the sparkline (Mon-anchored, Uzbek).
  static const List<String> mockWeekdayLabels = [
    'Du',
    'Se',
    'Ch',
    'Pa',
    'Ju',
    'Sh',
    'Ya',
  ];

  /// Sum of [mockRevenueSeries] — the hero number.
  static double get mockWeekRevenue =>
      mockRevenueSeries.fold(0, (sum, v) => sum + v);

  /// Period-over-period delta for the hero card (this week vs last week).
  static const double mockSalesDeltaPercent = 18.4;

  // ---- KPI deltas (small trend chips on each tile) ------------------------

  /// Keyed by KPI slug — the delta % shown as a `+x%` / `-x%` chip on each
  /// 2×2 grid card. `null` ⇒ no chip (new metric, no comparison yet).
  static const Map<String, double?> mockKpiDeltas = {
    'revenue': 18.4,
    'orders': 12.0,
    'pending': -8.0,
    'products': null,
  };

  // ---- Seller leaderboard -------------------------------------------------

  /// This week's top sellers by revenue. The entry with [isMe] is the current
  /// shop and is rendered highlighted; the backend will inject the real shop
  /// row (which may sit outside the visible top-N, in which case it's pinned
  /// at the bottom with its true rank).
  static const List<LeaderboardEntry> mockLeaderboard = [
    LeaderboardEntry(
      rank: 1,
      shopName: 'Bravo Mebel',
      revenue: 84_300_000,
      deltaPercent: 9.2,
    ),
    LeaderboardEntry(
      rank: 2,
      shopName: 'Soft Home',
      revenue: 71_900_000,
      deltaPercent: 4.1,
    ),
    LeaderboardEntry(
      rank: 3,
      shopName: 'Komfort Uy',
      revenue: 63_500_000,
      deltaPercent: -2.3,
    ),
    LeaderboardEntry(
      rank: 4,
      shopName: 'Zumar Mebel',
      revenue: 42_300_000,
      deltaPercent: 18.4,
      isMe: true,
    ),
    LeaderboardEntry(
      rank: 5,
      shopName: 'Klassik Dizayn',
      revenue: 38_700_000,
      deltaPercent: 1.0,
    ),
  ];

  // ---- Achievements -------------------------------------------------------

  /// Gamified milestones. `progress` is 0..1; `unlocked` flips the visual to
  /// a filled, celebratory state. `current`/`target` drive the "x / y" copy
  /// and `reward` describes what completing the milestone unlocks — both shown
  /// on the dedicated achievements screen. The mix below shows earned, nearly
  /// there, and locked, so the journey reads as real.
  static const List<Achievement> mockAchievements = [
    Achievement(
      icon: Iconsax.medal_star,
      title: 'Birinchi savdo',
      caption: 'Birinchi buyurtmangiz',
      current: 1,
      target: 1,
      unlocked: true,
      reward:
          "Profilingizda \"Faol sotuvchi\" nishoni paydo bo'ladi va "
          "do'koningiz qidiruvda biroz yuqori ko'rsatiladi.",
    ),
    Achievement(
      icon: Iconsax.crown_1,
      title: '10 ta buyurtma',
      caption: 'Bajarildi',
      current: 10,
      target: 10,
      unlocked: true,
      reward:
          "Komissiya 1 oy davomida 1% ga kamayadi va do'koningizga "
          "\"Ishonchli\" belgisi beriladi.",
    ),
    Achievement(
      icon: Iconsax.star_1,
      title: 'Reyting yulduzi',
      caption: "4.8 / 5.0 o'rtacha reyting",
      current: 48,
      target: 50,
      unlocked: false,
      reward:
          "5.0 reytingga yetsangiz do'koningiz bosh sahifadagi "
          "\"Tavsiya etilgan\" bo'limiga chiqadi.",
    ),
    Achievement(
      icon: Iconsax.box_tick,
      title: '50 ta mahsulot',
      caption: 'Katalogni to\'ldiring',
      current: 18,
      target: 50,
      unlocked: false,
      reward:
          "50 ta faol mahsulotga yetsangiz keyingi tarifga 20% chegirma "
          "va bitta bepul reklama bannerini olasiz.",
    ),
    Achievement(
      icon: Iconsax.flash_1,
      title: 'Tez yetkazuvchi',
      caption: '24 soat ichida tayyorlash',
      current: 7,
      target: 10,
      unlocked: false,
      reward:
          "Mahsulotlaringizda \"Tez yetkazib beruvchi\" yorlig'i "
          "ko'rsatiladi — bu xaridorlar ishonchini oshiradi.",
    ),
    Achievement(
      icon: Iconsax.wallet_check,
      title: '100 mln aylanma',
      caption: 'Jami savdo hajmi',
      current: 64,
      target: 100,
      unlocked: false,
      reward:
          "Premium sotuvchilar klubiga qo'shilasiz: shaxsiy menejer va "
          "bosh sahifada ustuvor joylashuv.",
    ),
  ];

  // ---- Top products -------------------------------------------------------

  /// Best-selling products this month. `imageUrl` reuses the same picsum seed
  /// convention as the mock catalog so thumbnails resolve in debug. `delta`
  /// is the period-over-period change in units sold.
  static const List<TopProduct> mockTopProducts = [
    TopProduct(
      name: 'Burchakli divan "Modern"',
      imageUrl: 'https://picsum.photos/seed/seller-sp-1-0/200/200',
      unitsSold: 14,
      revenue: 33_600_000,
      deltaPercent: 24.0,
    ),
    TopProduct(
      name: 'Yumshoq krovat "Aurora"',
      imageUrl: 'https://picsum.photos/seed/seller-sp-2-0/200/200',
      unitsSold: 9,
      revenue: 21_150_000,
      deltaPercent: 8.0,
    ),
    TopProduct(
      name: 'Oshxona stoli "Nordik"',
      imageUrl: 'https://picsum.photos/seed/seller-sp-3-0/200/200',
      unitsSold: 7,
      revenue: 9_800_000,
      deltaPercent: -5.0,
    ),
  ];
}

@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.shopName,
    required this.revenue,
    required this.deltaPercent,
    this.isMe = false,
  });

  final int rank;
  final String shopName;
  final num revenue;
  final double deltaPercent;

  /// `true` for the current shop's row — rendered with the Indigo highlight.
  final bool isMe;

  /// Competitors stay anonymous: only the first letter of each word survives,
  /// the rest become bullets ("Bravo Mebel" → "B•••• M••••"). The current
  /// shop ([isMe]) always shows its real name.
  String get displayName {
    if (isMe) return shopName;
    return shopName
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0]}${'•' * (w.length - 1)}')
        .join(' ');
  }
}

@immutable
class Achievement {
  const Achievement({
    required this.icon,
    required this.title,
    required this.caption,
    required this.current,
    required this.target,
    required this.unlocked,
    required this.reward,
  });

  final IconData icon;
  final String title;
  final String caption;

  /// Progress numerator / denominator — drives the "x / y" copy and the ring.
  final int current;
  final int target;
  final bool unlocked;

  /// What completing this milestone unlocks — shown on the achievements
  /// screen so the seller sees *why* it's worth chasing.
  final String reward;

  /// 0..1 fraction for the progress ring / bar.
  double get progress => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);
}

@immutable
class TopProduct {
  const TopProduct({
    required this.name,
    required this.imageUrl,
    required this.unitsSold,
    required this.revenue,
    required this.deltaPercent,
  });

  final String name;
  final String imageUrl;
  final int unitsSold;
  final num revenue;

  /// Period-over-period change in units sold (e.g. `24.0` ⇒ "+24%").
  final double deltaPercent;
}
