import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/dashboard_snapshot.dart';
import '../../../../shared/repositories/seller_dashboard_repository.dart';
import '../data/dashboard_models.dart';
import '../widgets/dashboard_kit.dart';
import '../widgets/seller_leaderboard.dart';

/// Full weekly seller leaderboard: Top-3 podium (reward hint) + ranked list
/// with sticky "Siz" row when the caller sits outside the top 20.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<LeaderboardBoard> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<SellerDashboardRepository>().fetchLeaderboard();
  }

  Future<void> _reload() async {
    setState(() {
      _future = sl<SellerDashboardRepository>().fetchLeaderboard();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2_copy, size: 20, color: c.ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          tr('dashboard.leaderboard_screen_title'),
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
      ),
      body: FutureBuilder<LeaderboardBoard>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('dashboard.leaderboard_load_error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.grey, fontFamily: AppFonts.seller),
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _reload, child: Text(tr('common.retry'))),
                  ],
                ),
              ),
            );
          }
          final board = snap.data!;
          final top = board.topSellers;
          final me = board.myRank;
          final inTop = me != null && top.any((e) => e.isMe);
          final listEntries = top
              .map(LeaderboardEntry.fromStanding)
              .toList(growable: false);
          final podium = listEntries.take(3).toList(growable: false);
          final rest = listEntries.length > 3
              ? listEntries.sublist(3)
              : const <LeaderboardEntry>[];

          return RefreshIndicator(
            onRefresh: _reload,
            color: c.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  board.metricDescription.isNotEmpty
                      ? board.metricDescription
                      : tr('dashboard.leaderboard_subtitle'),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    color: c.grey,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                if (podium.isEmpty)
                  DashCard(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      tr('dashboard.leaderboard_empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 14,
                        color: c.grey,
                      ),
                    ),
                  )
                else ...[
                  _Podium(entries: podium),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.gift, size: 14, color: c.gold),
                      const SizedBox(width: 6),
                      Text(
                        tr('dashboard.leaderboard_podium_hint'),
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.gold,
                        ),
                      ),
                    ],
                  ),
                ],
                if (rest.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  SellerLeaderboard(entries: rest),
                ],
                if (me != null && !inTop) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '···',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: c.greySoft,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SellerLeaderboard(
                    entries: [LeaderboardEntry.fromStanding(me)],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Display order: 2nd · 1st · 3rd for classic podium silhouette.
    LeaderboardEntry? first;
    LeaderboardEntry? second;
    LeaderboardEntry? third;
    for (final e in entries) {
      if (e.rank == 1) first = e;
      if (e.rank == 2) second = e;
      if (e.rank == 3) third = e;
    }
    // Fallback if ranks aren't exactly 1/2/3 (sparse board).
    first ??= entries.isNotEmpty ? entries[0] : null;
    second ??= entries.length > 1 ? entries[1] : null;
    third ??= entries.length > 2 ? entries[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _PodiumSlot(entry: second, place: 2, height: 118)),
        const SizedBox(width: 8),
        Expanded(child: _PodiumSlot(entry: first, place: 1, height: 148)),
        const SizedBox(width: 8),
        Expanded(child: _PodiumSlot(entry: third, place: 3, height: 100)),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.place,
    required this.height,
  });

  final LeaderboardEntry? entry;
  final int place;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final medals = <int, (Color, Color)>{
      1: (c.gold, c.goldBg),
      2: (c.silver, c.silverBg),
      3: (c.bronze, c.bronzeBg),
    };
    final (fg, bg) = medals[place]!;
    if (entry == null) {
      return SizedBox(height: height + 72);
    }
    final me = entry!.isMe;
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(Iconsax.medal_star, size: 24, color: fg),
            ),
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: fg.withValues(alpha: 0.35)),
                ),
                child: Icon(Iconsax.gift, size: 11, color: fg),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          entry!.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: me ? c.primary : c.ink,
          ),
        ),
        if (me) ...[
          const SizedBox(height: 2),
          Text(
            tr('dashboard.leaderboard_you'),
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: c.primary,
            ),
          ),
        ],
        const SizedBox(height: 2),
        Text(
          tr(
            'common.currency_som_2',
            namedArgs: {'amount': DashKit.compactMoney(entry!.revenue)},
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 11,
            color: c.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          width: double.infinity,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: fg.withValues(alpha: 0.25)),
          ),
          child: Text(
            '$place',
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: place == 1 ? 28 : 22,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ],
    );
  }
}
