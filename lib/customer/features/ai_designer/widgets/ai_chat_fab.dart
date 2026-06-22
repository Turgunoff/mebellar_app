import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

/// Standalone AI assistant FAB for the home screen: a Lottie robot that floats
/// directly over the feed with no card or puck behind it. A blurred silhouette
/// drop shadow keeps it legible over both light and dark product imagery, and a
/// gentle bob gives it a "hovering" feel. Tapping opens the designer chat.
class AiChatFab extends StatefulWidget {
  const AiChatFab({super.key});

  @override
  State<AiChatFab> createState() => _AiChatFabState();
}

class _AiChatFabState extends State<AiChatFab>
    with SingleTickerProviderStateMixin {
  // Robot artwork box, trimmed from the old 58px puck so it sits lighter over
  // the cards behind it.
  static const double _robotSize = 56;
  // Pads the tap target up to ≥48px (56 + 2*8 = 72) and leaves room for the bob
  // + shadow blur to paint without clipping the corner.
  static const double _tapPadding = 8;
  static const double _bob = 4;

  static const String _asset = 'assets/lottie/ai_chat_bot.json';

  late final AnimationController _controller;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -_bob, end: _bob).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/ai-designer-chat'),
      child: Padding(
        padding: const EdgeInsets.all(_tapPadding),
        child: RepaintBoundary(
          child: SizedBox(
            width: _robotSize,
            height: _robotSize,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Grounded drop shadow: a blurred dark silhouette of the bot,
                // held static (first frame) so only the foreground robot
                // animates — and so the robot lifts away from it on the up-beat.
                Transform.translate(
                  offset: const Offset(0, _bob),
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.45),
                        BlendMode.srcIn,
                      ),
                      child: Lottie.asset(_asset, fit: BoxFit.contain,
                          animate: false),
                    ),
                  ),
                ),
                // Foreground robot, bobbing up and down to read as "floating".
                AnimatedBuilder(
                  animation: _float,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _float.value),
                    child: child,
                  ),
                  child: Lottie.asset(_asset, fit: BoxFit.contain, repeat: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
