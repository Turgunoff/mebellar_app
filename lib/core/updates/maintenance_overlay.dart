import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../i18n/i18n.dart';

/// Full-screen, non-dismissible maintenance surface — shown when the operator
/// freezes the marketplace (`maintenance.enabled`).
///
/// Deliberately distinct from the force-update overlay: a deep, opaque slate
/// background (not frosted glass), a warm gold "under maintenance" icon, NO
/// action buttons, and a subtle bouncing-dots indicator that conveys the app is
/// waiting to come back. Because there is nothing to do but wait, restarting is
/// the implicit retry. [PopScope] blocks the Android back button; the gate
/// mounts above the Navigator so nothing underneath is reachable.
class MaintenanceOverlay extends StatelessWidget {
  const MaintenanceOverlay({super.key, required this.message});

  /// Operator-set copy from the backend. Falls back to a localized default when
  /// blank (e.g. an unfetched / cleared message).
  final String message;

  // A guaranteed-dark branded takeover, so the palette is fixed constants (like
  // the brand accent) rather than theme tokens — it reads the same in light and
  // dark mode.
  static const Color _bg = Color(0xFF15171E); // deep elegant slate
  static const Color _gold = Color(0xFFE0B26C); // soft warm gold

  @override
  Widget build(BuildContext context) {
    final body = message.trim().isNotEmpty
        ? message.trim()
        : tr('maintenance.fallback_message');

    return PopScope(
      canPop: false,
      child: Material(
        color: _bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: _gold.withValues(alpha: 0.28)),
                  ),
                  child: const Icon(
                    Icons.handyman_rounded,
                    size: 46,
                    color: _gold,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  tr('maintenance.title'),
                  textAlign: TextAlign.center,
                  style: PremiumTokens.display(size: 26, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: PremiumTokens.body(
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 40),
                const _BouncingDots(color: _gold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three softly bouncing dots — a calm "we're working on it" indicator that
/// reads as more intentional than a spinner. Pure animation, no interaction.
class _BouncingDots extends StatefulWidget {
  const _BouncingDots({required this.color});

  final Color color;

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Stagger each dot a third of a cycle apart; lift only on the
            // up-swing so they bounce rather than oscillate symmetrically.
            final phase = (_controller.value - i * 0.18) % 1.0;
            final lift = math.max(0.0, math.sin(phase * 2 * math.pi));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.5),
              child: Transform.translate(
                offset: Offset(0, -6 * lift),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.4 + 0.6 * lift),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
