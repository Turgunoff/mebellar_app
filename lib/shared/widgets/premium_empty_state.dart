import 'package:flutter/material.dart';

import '../../core/theme/premium_tokens.dart';

class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonPressed,
    this.bottomPadding = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Optional call-to-action. When [buttonText] or [onButtonPressed] is null
  /// the button is omitted entirely.
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    // Dead-centre the content within the available body height (between the
    // header/status bar and the bottom nav). The scroll view + min-height
    // constraint keeps it centred on tall screens yet lets it scroll instead
    // of overflowing on short ones (landscape / split-screen).
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Bare glyph, no circular fill — a soft, low-opacity brand
          // tint keeps it present without competing with the title.
          Icon(
            icon,
            size: 64,
            color: PremiumTokens.accent.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: PremiumTokens.display(
              size: 26,
              color: pt.dark,
              height: 1.2,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Narrower measure than the title — extra inset gives the
          // body copy an editorial column. 3 lines: uz copy regularly
          // needs the third; a mid-word "…" cut reads broken.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: PremiumTokens.body(size: 15, color: pt.grey, height: 1.5),
            ),
          ),
          if (buttonText != null && onButtonPressed != null) ...[
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: onButtonPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: PremiumTokens.accent,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  textStyle: PremiumTokens.body(
                    size: 15,
                    weight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                child: Text(buttonText!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
