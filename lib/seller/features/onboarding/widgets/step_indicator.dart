import 'package:flutter/material.dart';

import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';

/// Continuous gradient progress bar for the seller onboarding wizard.
///
/// A single rounded bar reads as more premium than segmented chunks and
/// scales gracefully if the wizard step count changes — `currentStep /
/// totalSteps` produces a smooth 0..1 fraction the bar animates to.
class OnboardingStepIndicator extends StatelessWidget {
  const OnboardingStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final fraction = totalSteps <= 0
        ? 0.0
        : (currentStep / totalSteps).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0, end: fraction),
        builder: (_, value, _) => ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 6,
            color: PremiumTokens.accent.withValues(alpha: 0.12),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [PremiumTokens.accent, PremiumTokens.accentDeep],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
