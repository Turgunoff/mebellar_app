import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../home/widgets/premium/premium_tokens.dart';

/// Animated AI assistant FAB for the home screen. A circular Lottie bot with a
/// soft terracotta glow; tapping opens the interior-designer chat.
class AiChatFab extends StatelessWidget {
  const AiChatFab({super.key});

  static const double _size = 58;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/ai-designer-chat'),
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: pt.surface,
          shape: BoxShape.circle,
          boxShadow: [
            // Brand-accent glow — the const accent doesn't flip in dark mode.
            BoxShadow(
              color: PremiumTokens.accent.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 1,
            ),
            // Base elevation shadow so the puck reads as a floating control.
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Lottie.asset(
            'assets/lottie/ai_chat_bot.json',
            fit: BoxFit.cover,
            repeat: true,
          ),
        ),
      ),
    );
  }
}
