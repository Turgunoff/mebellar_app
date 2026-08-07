import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/theme/premium_tokens.dart';

/// Frosted toast that slides down from under the status bar.
///
/// Replaces the stock bottom [SnackBar] on screens whose bottom edge is
/// occupied by a persistent action bar (product detail), where a SnackBar
/// would cover the primary CTA. Tapping anywhere on the toast fires
/// [onAction]; a quick upward flick dismisses it early.
///
/// Inserted into the **root** overlay so it paints above every route and
/// survives a pop of the screen that spawned it — pass callbacks that don't
/// capture a disposable [BuildContext] (e.g. capture `GoRouter.of(context)`
/// before showing).
void showTopToast(
  BuildContext context, {
  required String message,
  IconData icon = Iconsax.bag_tick,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 3200),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  // One toast at a time — a new call instantly replaces the visible one.
  // Removing the entry disposes _TopToastState, which cancels its timer and
  // controller, so the replaced toast can never double-remove itself.
  _activeToast?.remove();
  _activeToast = null;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopToast(
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      onDismissed: () {
        if (_activeToast == entry) _activeToast = null;
        entry.remove();
      },
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

OverlayEntry? _activeToast;

class _TopToast extends StatefulWidget {
  const _TopToast({
    required this.message,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 240),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  Timer? _hideTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _hideTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _hideTimer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  void _handleTap() {
    widget.onAction?.call();
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        // -1 of own height: with the status-bar padding inside the slide,
        // the toast starts fully off-screen and settles under the notch.
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(_curve),
        child: FadeTransition(
          opacity: _curve,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 0),
            child: Material(
              type: MaterialType.transparency,
              child: Semantics(
                container: true,
                liveRegion: true,
                child: GestureDetector(
                  onTap: widget.onAction != null ? _handleTap : _dismiss,
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < -150) _dismiss();
                  },
                  child: _ToastCard(
                    isDark: isDark,
                    pt: pt,
                    icon: widget.icon,
                    message: widget.message,
                    actionLabel: widget.actionLabel,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.isDark,
    required this.pt,
    required this.icon,
    required this.message,
    required this.actionLabel,
  });

  final bool isDark;
  final PremiumTokens pt;
  final IconData icon;
  final String message;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    // Frosted glass recipe mirrors GlassBottomNav so the two floating
    // surfaces read as one design system.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xB31E1E1E)
                  : Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PremiumTokens.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 20, color: PremiumTokens.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTokens.body(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: pt.dark,
                      height: 1.25,
                    ),
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: PremiumTokens.accent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      actionLabel!,
                      style: PremiumTokens.body(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
