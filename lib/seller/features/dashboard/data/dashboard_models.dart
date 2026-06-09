import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../shared/models/dashboard_snapshot.dart';

/// Maps a backend achievement icon token (seeded in migration 0015) to an
/// Iconsax glyph. Unknown tokens fall back to a medal, so a new server-side
/// achievement still renders something sensible without an app update.
IconData achievementIcon(String token) => switch (token) {
  'medal' => Iconsax.medal_star,
  'crown' => Iconsax.crown_1,
  'cup' => Iconsax.cup,
  'box' => Iconsax.box,
  'box_tick' => Iconsax.box_tick,
  'wallet' => Iconsax.wallet_check,
  'star' => Iconsax.star_1,
  'flash' => Iconsax.flash_1,
  _ => Iconsax.medal_star,
};

/// View-model for the dashboard achievement strip + the detailed screen, built
/// from the backend [AchievementProgress]. Revenue milestones are collapsed to
/// millions so the "x / y" counter reads cleanly (e.g. "2 / 5" for a 5M goal,
/// matching the "5 mln aylanma" title).
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

  /// What completing this milestone unlocks — shown on the achievements screen.
  final String reward;

  /// 0..1 fraction for the progress ring / bar.
  double get progress => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);

  factory Achievement.fromProgress(AchievementProgress p) {
    final divisor = p.requirementType == 'revenue_realized' ? 1000000.0 : 1.0;
    final rawTarget = (p.threshold / divisor).round();
    final target = rawTarget <= 0 ? 1 : rawTarget;
    final current = (p.progress / divisor).floor().clamp(0, target).toInt();
    return Achievement(
      // Status caption, not the "x / y" counter — the detail screen renders the
      // counter separately, so duplicating it here would show it twice.
      icon: achievementIcon(p.icon),
      title: p.titleUz,
      caption: p.unlocked ? 'Bajarildi' : 'Davom etmoqda',
      current: current,
      target: target,
      unlocked: p.unlocked,
      reward: p.descriptionUz ?? '',
    );
  }
}

/// View-model for one leaderboard row. The server already masks competitor
/// names (the current shop arrives with its real name + [isMe]), so
/// [displayName] trusts the value verbatim — no client-side anonymisation.
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.shopName,
    required this.revenue,
    this.deltaPercent,
    this.isMe = false,
  });

  final int rank;
  final String shopName;
  final num revenue;
  final double? deltaPercent;

  /// `true` for the current shop's row — rendered with the Indigo highlight.
  final bool isMe;

  String get displayName => shopName;

  factory LeaderboardEntry.fromStanding(LeaderboardStanding s) =>
      LeaderboardEntry(
        rank: s.rank,
        shopName: s.shopName,
        revenue: s.revenue,
        deltaPercent: s.deltaPercent,
        isMe: s.isMe,
      );
}

/// View-model for one "Eng ko'p sotilgan" row. [imageUrl] may be null (no photo
/// on the product) — the widget shows a placeholder.
@immutable
class TopProduct {
  const TopProduct({
    required this.name,
    required this.imageUrl,
    required this.unitsSold,
    required this.revenue,
    this.deltaPercent,
  });

  final String name;
  final String? imageUrl;
  final int unitsSold;
  final num revenue;

  /// Period-over-period change (e.g. `24.0` ⇒ "+24%"); null ⇒ "—" chip.
  final double? deltaPercent;

  factory TopProduct.fromStat(TopProductStat s) => TopProduct(
    name: s.name,
    imageUrl: s.image,
    unitsSold: s.unitsSold,
    revenue: s.revenue,
    deltaPercent: s.deltaPercent,
  );
}
