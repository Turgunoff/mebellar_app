import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../data/dashboard_models.dart';
import 'dashboard_kit.dart';

/// Weekly seller leaderboard. Top-3 ranks get a coloured medal disc (gold /
/// silver / bronze); the current shop's row ([LeaderboardEntry.isMe]) is
/// lifted onto a soft-Indigo highlight so the seller spots their position at
/// a glance.
class SellerLeaderboard extends StatelessWidget {
  const SellerLeaderboard({super.key, required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return DashCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.divider),
            _LeaderRow(entry: entries[i]),
          ],
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final dark = c.brightness == Brightness.dark;
    final me = entry.isMe;
    // The me-row highlight is a soft indigo wash: the fixed light tint on light
    // mode, a translucent brand indigo over the dark surface on dark mode.
    final meBg = dark
        ? c.primary.withValues(alpha: 0.20)
        : DashKit.indigoTint;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: me ? meBg : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _RankBadge(rank: entry.rank, highlight: me),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: me ? FontWeight.w700 : FontWeight.w600,
                          // On the dark indigo wash a near-white ink reads
                          // better than the deep indigo used on the light tint.
                          color: me
                              ? (dark ? c.ink : DashKit.indigoDeep)
                              : c.ink,
                          height: 1.15,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (me) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: DashKit.indigo,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tr('dashboard.leaderboard_you'),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  tr(
                    'common.currency_som_2',
                    namedArgs: {
                      'amount': DashKit.compactMoney(entry.revenue),
                    },
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.grey,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DashTrendChip(deltaPercent: entry.deltaPercent, compact: true),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.highlight});

  final int rank;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    // Top-3 medal (fg, bg) tints, theme-aware. Beyond 3rd, a plain neutral
    // disc with the rank number.
    final medals = <int, (Color, Color)>{
      1: (c.gold, c.goldBg),
      2: (c.silver, c.silverBg),
      3: (c.bronze, c.bronzeBg),
    };
    final medal = medals[rank];
    final isTop3 = medal != null;
    final fg = isTop3 ? medal.$1 : c.grey;
    final bg = isTop3 ? medal.$2 : (highlight ? c.surface : c.fillSoft);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: isTop3
          ? Icon(Iconsax.medal_star, size: 18, color: fg)
          : Text(
              '$rank',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg,
                height: 1.0,
              ),
            ),
    );
  }
}
