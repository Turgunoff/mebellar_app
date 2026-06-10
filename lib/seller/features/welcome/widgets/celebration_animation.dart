import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Purely code-generated celebration animation: a gold trophy badge that
/// springs in and breathes, expanding indigo "pulse" rings, and a one-shot
/// confetti burst that fans out and falls under gravity.
///
/// Deliberately self-contained — it owns its controllers and paints with
/// [CustomPainter], no external assets. To swap in a Lottie file later,
/// replace this whole widget with `Lottie.asset('assets/lottie/foo.json')`
/// at the single call-site in `SellerWelcomeScreen`; nothing else depends on
/// its internals.
class CelebrationAnimation extends StatefulWidget {
  const CelebrationAnimation({super.key, this.size = 220});

  /// Side length of the square animation canvas. The trophy badge and confetti
  /// spread scale from this.
  final double size;

  @override
  State<CelebrationAnimation> createState() => _CelebrationAnimationState();
}

class _CelebrationAnimationState extends State<CelebrationAnimation>
    with TickerProviderStateMixin {
  // One-shot: drives the spring-in trophy and the confetti burst.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  // Continuous: drives the breathing trophy + the expanding pulse rings.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final List<_Confetto> _confetti = _buildConfetti();

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    _loop.repeat();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  static List<_Confetto> _buildConfetti() {
    // Fixed seed → the burst looks identical every time but still reads as
    // organic. 28 pieces is enough to feel festive without overdraw.
    final rnd = math.Random(7);
    const colors = [
      AppColors.sellerPrimary,
      AppColors.sellerPrimaryBright,
      AppColors.sellerGold,
      AppColors.sellerGoldBright,
      AppColors.sellerPositive,
    ];
    return List.generate(28, (i) {
      final angle = (i / 28) * 2 * math.pi + rnd.nextDouble() * 0.5;
      return _Confetto(
        angle: angle,
        distance: 0.55 + rnd.nextDouble() * 0.45,
        color: colors[i % colors.length],
        size: 6 + rnd.nextDouble() * 7,
        spin: (rnd.nextDouble() * 4 - 2) * math.pi,
        delay: rnd.nextDouble() * 0.15,
        rounded: i.isEven,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _loop]),
        builder: (context, _) {
          final spring = Curves.elasticOut.transform(
            _entrance.value.clamp(0.0, 1.0),
          );
          final breathe = 1 + 0.035 * math.sin(_loop.value * 2 * math.pi);
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding pulse rings (continuous).
              CustomPaint(
                size: Size.square(widget.size),
                painter: _PulseRingsPainter(progress: _loop.value),
              ),
              // Confetti burst (one-shot, follows the entrance).
              CustomPaint(
                size: Size.square(widget.size),
                painter: _ConfettiPainter(
                  progress: Curves.easeOut.transform(
                    _entrance.value.clamp(0.0, 1.0),
                  ),
                  pieces: _confetti,
                ),
              ),
              // Trophy badge: springs in, then breathes.
              Transform.scale(
                scale: spring * breathe,
                child: _TrophyBadge(diameter: widget.size * 0.46),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Circular gold-gradient badge holding the trophy glyph.
class _TrophyBadge extends StatelessWidget {
  const _TrophyBadge({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [AppColors.sellerGoldBright, AppColors.sellerGold],
          center: Alignment(-0.2, -0.3),
          radius: 0.95,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.sellerGold.withValues(alpha: 0.45),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.emoji_events_rounded,
        size: diameter * 0.56,
        color: Colors.white,
      ),
    );
  }
}

/// Three concentric rings that grow outward and fade, restarting on the loop.
class _PulseRingsPainter extends CustomPainter {
  _PulseRingsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    for (var i = 0; i < 3; i++) {
      // Stagger the rings by a third of the cycle.
      final t = (progress + i / 3) % 1.0;
      final radius = maxRadius * (0.35 + t * 0.65);
      final opacity = (1 - t) * 0.28;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.sellerPrimary.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulseRingsPainter old) => old.progress != progress;
}

/// One confetto descriptor for the burst.
class _Confetto {
  const _Confetto({
    required this.angle,
    required this.distance,
    required this.color,
    required this.size,
    required this.spin,
    required this.delay,
    required this.rounded,
  });

  /// Launch direction from centre, radians.
  final double angle;

  /// Peak travel distance as a fraction of the canvas half-width.
  final double distance;
  final Color color;
  final double size;

  /// Total rotation across the burst, radians.
  final double spin;

  /// Per-piece launch delay (0–1) so the burst doesn't fire as one rigid ring.
  final double delay;
  final bool rounded;
}

/// Paints the confetti burst: each piece fans out from centre, decelerates,
/// then drops under gravity while spinning and fading.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.pieces});

  final double progress;
  final List<_Confetto> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final reach = size.width / 2;
    for (final c in pieces) {
      // Re-base each piece's progress past its launch delay.
      final span = 1 - c.delay;
      final local = ((progress - c.delay) / span).clamp(0.0, 1.0);
      if (local <= 0) continue;

      // Ease-out radial travel + gravity pulling pieces down over time.
      final travel = (1 - math.pow(1 - local, 2).toDouble()) * c.distance;
      final dx = math.cos(c.angle) * travel * reach;
      final gravity = local * local * reach * 0.9;
      final dy = math.sin(c.angle) * travel * reach + gravity;
      final pos = center + Offset(dx, dy);

      final opacity = (1 - local).clamp(0.0, 1.0);
      final paint = Paint()..color = c.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(c.spin * local);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: c.size,
        height: c.size * 0.6,
      );
      if (c.rounded) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(c.size * 0.3)),
          paint,
        );
      } else {
        canvas.drawRect(rect, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
