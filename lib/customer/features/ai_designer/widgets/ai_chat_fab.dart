import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../../core/i18n/i18n.dart';
import '../../home/widgets/premium/premium_tokens.dart';

/// Standalone AI assistant FAB for the home screen: a Lottie robot that floats
/// directly over the feed with no card or puck behind it. A blurred silhouette
/// drop shadow keeps it legible over both light and dark product imagery, and a
/// gentle bob gives it a "hovering" feel. Tapping opens the designer chat.
///
/// When [showcaseKey] is set, the FAB is wrapped in a [Showcase] so the
/// first-launch home tour can spotlight it after the AR demo step.
class AiChatFab extends StatefulWidget {
  const AiChatFab({super.key, this.showcaseKey});

  final GlobalKey? showcaseKey;

  @override
  State<AiChatFab> createState() => _AiChatFabState();
}

class _AiChatFabState extends State<AiChatFab>
    with SingleTickerProviderStateMixin {
  static const double _robotSize = 56;
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
    _float = Tween<double>(
      begin: -_bob,
      end: _bob,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openChat(BuildContext context) => context.push('/ai-designer-chat');

  @override
  Widget build(BuildContext context) {
    final fab = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openChat(context),
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
                Transform.translate(
                  offset: const Offset(0, _bob),
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.45),
                        BlendMode.srcIn,
                      ),
                      child: Lottie.asset(
                        _asset,
                        fit: BoxFit.contain,
                        animate: false,
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _float,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _float.value),
                    child: child,
                  ),
                  child: Lottie.asset(
                    _asset,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final key = widget.showcaseKey;
    if (key == null) return fab;

    final pt = PremiumTokens.of(context);
    return Showcase(
      key: key,
      title: tr('home.ai_agent_showcase_title'),
      description: tr('home.ai_agent_showcase_desc'),
      targetShapeBorder: const CircleBorder(),
      targetPadding: const EdgeInsets.all(6),
      tooltipBackgroundColor: pt.surface,
      textColor: pt.dark,
      tooltipBorderRadius: BorderRadius.circular(16),
      titleTextStyle: PremiumTokens.display(size: 16, letterSpacing: -0.2),
      descTextStyle: PremiumTokens.body(size: 13, height: 1.4, color: pt.grey),
      onTargetClick: () => _openChat(context),
      disposeOnTap: true,
      child: fab,
    );
  }
}
