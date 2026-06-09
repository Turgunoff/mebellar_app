import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../data/dashboard_mock.dart';
import '../widgets/dashboard_kit.dart';

/// Full "Yutuqlar" screen reached from the dashboard's "Hammasi" link.
///
/// Shows an overall-progress header, then every milestone split into earned
/// and not-yet-earned groups. Each card spells out its progress *and* the
/// reward for completing it, so the seller sees exactly what they're chasing.
///
/// Mock-driven for now (see [DashboardMock.mockAchievements]); the backend
/// will swap in `GET /seller/dashboard/achievements`.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, this.achievements});

  /// Defaults to the mock list — injectable so tests/preview can vary it.
  final List<Achievement>? achievements;

  @override
  Widget build(BuildContext context) {
    final items = achievements ?? DashboardMock.mockAchievements;
    final unlocked = items.where((a) => a.unlocked).toList();
    final locked = items.where((a) => !a.unlocked).toList();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: const _AchievementsAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _ProgressHeader(unlocked: unlocked.length, total: items.length),
          if (unlocked.isNotEmpty) ...[
            const SizedBox(height: 24),
            _GroupLabel(
              icon: Iconsax.medal_star,
              text: 'Qo\'lga kiritilgan',
              count: unlocked.length,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < unlocked.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _AchievementCard(item: unlocked[i]),
            ],
          ],
          if (locked.isNotEmpty) ...[
            const SizedBox(height: 24),
            _GroupLabel(
              icon: Iconsax.lock_1,
              text: 'Davom etmoqda',
              count: locked.length,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < locked.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _AchievementCard(item: locked[i]),
            ],
          ],
        ],
      ),
    );
  }
}

class _AchievementsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _AchievementsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: DashKit.ink,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left_2, size: 22, color: DashKit.ink),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        'Yutuqlar',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: DashKit.ink,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Indigo gradient summary card: "x / y yutuq" + an overall progress bar.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : unlocked / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4554C4), DashKit.indigoDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: DashKit.indigo.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Iconsax.cup, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$unlocked / $total yutuq',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qo\'lga kiritildi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({
    required this.icon,
    required this.text,
    required this.count,
  });

  final IconData icon;
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: DashKit.grey),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: DashKit.ink,
            height: 1.1,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: DashKit.greyMid,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.item});

  final Achievement item;

  @override
  Widget build(BuildContext context) {
    final unlocked = item.unlocked;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked
              ? DashKit.gold.withValues(alpha: 0.35)
              : DashKit.hairline,
        ),
        boxShadow: DashKit.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Badge(item: item),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: DashKit.ink,
                              height: 1.15,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (unlocked) const _DoneChip(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.caption,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: DashKit.grey,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Progress row only for locked goals — earned ones show the chip.
          if (!unlocked) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFF0F0F2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        DashKit.indigo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${item.current} / ${item.target}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DashKit.indigoDeep,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _RewardBox(reward: item.reward, unlocked: unlocked),
        ],
      ),
    );
  }
}

/// The "what you get" panel under each achievement.
class _RewardBox extends StatelessWidget {
  const _RewardBox({required this.reward, required this.unlocked});

  final String reward;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? DashKit.goldBg : DashKit.indigoTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Iconsax.gift,
            size: 16,
            color: unlocked ? DashKit.gold : DashKit.indigoDeep,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  unlocked ? 'Olingan mukofot' : 'Mukofot',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: unlocked ? DashKit.gold : DashKit.indigoDeep,
                    height: 1.1,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reward,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: DashKit.ink,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneChip extends StatelessWidget {
  const _DoneChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DashKit.positiveBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 13, color: DashKit.positive),
          SizedBox(width: 3),
          Text(
            'Bajarildi',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: DashKit.positive,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular badge — gold gradient when unlocked, locked icon inside a
/// progress ring otherwise. Mirrors the dashboard strip badge but larger.
class _Badge extends StatelessWidget {
  const _Badge({required this.item});

  final Achievement item;

  @override
  Widget build(BuildContext context) {
    final unlocked = item.unlocked;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!unlocked)
            SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(
                painter: _RingPainter(progress: item.progress),
              ),
            ),
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: unlocked
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFCB52), DashKit.gold],
                    )
                  : null,
              color: unlocked ? null : const Color(0xFFF1F1F4),
            ),
            child: Icon(
              item.icon,
              size: 22,
              color: unlocked ? Colors.white : DashKit.greyMid,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFEDEDF0)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = DashKit.indigo
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
