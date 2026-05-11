import 'package:flutter/material.dart';

/// Continuous progress bar for the seller onboarding wizard.
///
/// Replaces the earlier 6-segment chunky bar. A single rounded
/// `LinearProgressIndicator` reads as more premium and scales gracefully if
/// the wizard step count changes — `currentStep / totalSteps` produces a
/// smooth 0..1 fraction the indicator animates to.
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
    final scheme = Theme.of(context).colorScheme;
    final fraction = totalSteps <= 0
        ? 0.0
        : (currentStep / totalSteps).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: fraction),
          builder: (_, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: scheme.primary.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
          ),
        ),
      ),
    );
  }
}
