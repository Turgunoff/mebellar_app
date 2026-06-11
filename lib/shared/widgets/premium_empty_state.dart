import 'package:flutter/material.dart';

import '../../customer/features/home/widgets/premium/premium_tokens.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - bottomPadding,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(32, 0, 32, bottomPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PremiumTokens.accent.withValues(alpha: 0.10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 44, color: PremiumTokens.accent),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: PremiumTokens.display(size: 22, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    // 3 lines — uz copy regularly needs the third; a mid-word
                    // "…" cut reads broken on the customer's main tabs.
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTokens.body(
                      size: 14,
                      color: pt.grey,
                      height: 1.5,
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
            ),
          ),
        );
      },
    );
  }
}
