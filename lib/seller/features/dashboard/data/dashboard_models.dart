import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../shared/models/dashboard_snapshot.dart';

/// Maps a backend achievement icon name to a FontAwesome glyph. The DB stores
/// only the name string (e.g. 'trophy', 'boxes-stacked'); this is the single
/// place that resolves it to an `IconData` for `FaIcon`. The 12 names below are
/// the seeded catalogue (app/services/achievements_seed.py); a handful of
/// legacy Iconsax-era tokens are aliased so stale cached rows still render, and
/// any unknown name falls back to a trophy — a new server-side achievement
/// shows something sensible without an app update.
FaIconData achievementIcon(String name) => switch (name) {
  // ── Seeded FontAwesome names ──
  'box' => FontAwesomeIcons.box,
  'boxes-stacked' => FontAwesomeIcons.boxesStacked,
  'award' => FontAwesomeIcons.award,
  'trophy' => FontAwesomeIcons.trophy,
  'medal' => FontAwesomeIcons.medal,
  'money-bill-wave' => FontAwesomeIcons.moneyBillWave,
  'wand-magic-sparkles' => FontAwesomeIcons.wandMagicSparkles,
  'cubes' => FontAwesomeIcons.cubes,
  'bolt' => FontAwesomeIcons.bolt,
  'star' => FontAwesomeIcons.star,
  'couch' => FontAwesomeIcons.couch,
  'crown' => FontAwesomeIcons.crown,
  // ── Legacy Iconsax-era tokens (pre-rebuild cached data) ──
  'cup' => FontAwesomeIcons.trophy,
  'box_tick' => FontAwesomeIcons.boxesStacked,
  'wallet' => FontAwesomeIcons.wallet,
  'flash' => FontAwesomeIcons.bolt,
  _ => FontAwesomeIcons.trophy,
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

  final FaIconData icon;
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

  /// Builds the view-model from the backend row. [lang] (the active UI locale,
  /// uz/ru/en) selects the localized title + reward; revenue milestones are
  /// collapsed to millions so the "x / y" counter reads cleanly.
  factory Achievement.fromProgress(AchievementProgress p, {String lang = 'uz'}) {
    final divisor = p.requirementType == 'revenue_realized' ? 1000000.0 : 1.0;
    final rawTarget = (p.threshold / divisor).round();
    final target = rawTarget <= 0 ? 1 : rawTarget;
    final current = (p.progress / divisor).floor().clamp(0, target).toInt();
    return Achievement(
      // Status caption, not the "x / y" counter — the detail screen renders the
      // counter separately, so duplicating it here would show it twice.
      icon: achievementIcon(p.icon),
      title: p.localizedTitle(lang),
      caption: p.unlocked
          ? tr('dashboard.achievement_done_chip')
          : 'Davom etmoqda',
      current: current,
      target: target,
      unlocked: p.unlocked,
      reward: p.localizedReward(lang),
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
