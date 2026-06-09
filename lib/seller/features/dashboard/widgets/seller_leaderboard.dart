import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../data/dashboard_mock.dart';
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
    return DashCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: DashKit.hairline),
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
    final me = entry.isMe;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: me ? DashKit.indigoTint : Colors.transparent,
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
                          color: me ? DashKit.indigoDeep : DashKit.ink,
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
                        child: const Text(
                          'Siz',
                          style: TextStyle(
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
                  '${DashKit.compactMoney(entry.revenue)} so\'m',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DashKit.grey,
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

  /// Top-3 medal tints. Beyond 3rd, a plain neutral disc with the number.
  static const _medals = <int, (Color, Color)>{
    1: (DashKit.gold, DashKit.goldBg),
    2: (DashKit.silver, DashKit.silverBg),
    3: (DashKit.bronze, DashKit.bronzeBg),
  };

  @override
  Widget build(BuildContext context) {
    final medal = _medals[rank];
    final isTop3 = medal != null;
    final fg = isTop3 ? medal.$1 : DashKit.grey;
    final bg = isTop3
        ? medal.$2
        : (highlight ? Colors.white : DashKit.fillSoft);
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
