import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../data/dashboard_mock.dart';
import 'dashboard_kit.dart';

/// Horizontally-scrolling row of achievement badges. Unlocked badges glow in
/// gold; locked ones show a desaturated icon wrapped in a progress ring so the
/// seller sees exactly how close they are to earning each one.
class AchievementsStrip extends StatelessWidget {
  const AchievementsStrip({super.key, required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        clipBehavior: Clip.none,
        itemCount: achievements.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _AchievementCard(item: achievements[i]),
      ),
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
      width: 116,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked
              ? DashKit.gold.withValues(alpha: 0.4)
              : DashKit.hairline,
        ),
        boxShadow: DashKit.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Badge(item: item),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: unlocked ? DashKit.ink : DashKit.grey,
              height: 1.1,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: DashKit.greyMid,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.item});

  final Achievement item;

  @override
  Widget build(BuildContext context) {
    final unlocked = item.unlocked;
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!unlocked)
            SizedBox(
              width: 52,
              height: 52,
              child: CustomPaint(
                painter: _RingPainter(progress: item.progress),
              ),
            ),
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: unlocked
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [DashKit.goldBright, DashKit.gold],
                    )
                  : null,
              color: unlocked ? null : DashKit.lockedBg,
            ),
            child: Icon(
              unlocked ? item.icon : Iconsax.lock_1,
              size: 20,
              color: unlocked ? Colors.white : DashKit.greyMid,
            ),
          ),
          if (unlocked)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: DashKit.positive,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 9,
                  color: Colors.white,
                ),
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
    final track = Paint()
      ..color = DashKit.ringTrack
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..color = DashKit.indigo
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // start at top (-90°)
      6.2832 * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
