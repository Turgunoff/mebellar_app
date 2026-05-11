import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'talker.dart';

const _bugFabColor = Color(0xFFC27A5F);

/// Wraps [child] with a debug-only floating bug button that opens the
/// [TalkerScreen] log viewer. The button is **draggable** — long-press-free
/// pan moves it; a tap opens Talker.
///
/// Designed for use as `MaterialApp.builder` (or `MaterialApp.router.builder`).
/// The builder's `context` sits above the Navigator, so we cannot push via
/// `Navigator.of(context)` — instead the caller passes the same
/// [GlobalKey<NavigatorState>] they wired into `MaterialApp.navigatorKey`
/// (or `GoRouter.navigatorKey`).
///
/// Position is held in memory only; it resets on hot restart. That's fine
/// for a dev-only affordance — adding persistence would mean a Hive box and
/// async boot, which isn't worth the complexity here.
class DebugTalkerOverlay extends StatefulWidget {
  const DebugTalkerOverlay({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget? child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<DebugTalkerOverlay> createState() => _DebugTalkerOverlayState();
}

class _DebugTalkerOverlayState extends State<DebugTalkerOverlay> {
  static const double _fabSize = 44;
  static const double _edgePad = 16;

  /// Null until the first build computes a default. We store and re-clamp
  /// on every build so rotation / split-screen resize can't strand the FAB
  /// off-screen.
  Offset? _pos;

  void _openTalker() {
    final nav = widget.navigatorKey.currentState;
    if (nav == null) {
      talker.warning('DebugTalkerOverlay tap: navigatorKey not attached');
      return;
    }
    nav.push(
      MaterialPageRoute<void>(builder: (_) => TalkerScreen(talker: talker)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.child ?? const SizedBox.shrink();
    if (!kDebugMode) return body;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final padding = MediaQuery.viewPaddingOf(ctx);

        final minX = _edgePad;
        final maxX = (w - _fabSize - _edgePad).clamp(minX, double.infinity);
        final minY = padding.top + _edgePad;
        final maxY = (h - _fabSize - padding.bottom - _edgePad)
            .clamp(minY, double.infinity);

        // Default: bottom-right (matches the original static placement).
        final defaultPos = Offset(maxX, maxY);
        final raw = _pos ?? defaultPos;
        final pos = Offset(
          raw.dx.clamp(minX, maxX),
          raw.dy.clamp(minY, maxY),
        );

        return Stack(
          children: [
            body,
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() {
                    _pos = Offset(
                      (pos.dx + details.delta.dx).clamp(minX, maxX),
                      (pos.dy + details.delta.dy).clamp(minY, maxY),
                    );
                  });
                },
                child: _BugFab(onTap: _openTalker),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BugFab extends StatelessWidget {
  const _BugFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bugFabColor,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.bug_report_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
