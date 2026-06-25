import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/celebration_animation.dart';

/// One-time celebratory screen shown the first time a freshly-approved seller
/// enters seller mode. Pure and callback-driven: it owns no persistence and no
/// navigation — the caller decides what "continue" means (mark the flag seen,
/// pop back to the dashboard). That keeps it trivially widget-testable and
/// lets the gate live entirely in the router.
///
/// Typography note: every `TextStyle` omits `fontFamily` so it inherits Plus
/// Jakarta Sans from the seller theme, matching the dashboard. Copy is Uzbek-
/// only and hardcoded, consistent with the rest of the seller surface.
class SellerWelcomeScreen extends StatelessWidget {
  const SellerWelcomeScreen({super.key, required this.onContinue});

  /// Invoked when the seller taps "Boshlash" (or dismisses with system back).
  final VoidCallback onContinue;

  void _continue() {
    HapticFeedback.lightImpact();
    onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    // The screen sits above the shell; system back must complete the flow
    // (mark seen + pop) rather than exit the app or leave the flag unset.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onContinue();
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const CelebrationAnimation(size: 240),
                const SizedBox(height: 36),
                Text(
                  tr('seller.welcome_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr('seller.welcome_subtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.grey,
                    height: 1.5,
                  ),
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _continue,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sellerPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      tr('seller.ar_onboarding_start'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
