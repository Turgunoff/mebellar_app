import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/premium_tokens.dart';
import '../bloc/onboarding_bloc.dart';
import 'onboarding_kit.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return StepActivation(
      step: OnboardingStep.welcome,
      builder: (context, animation) {
        final heroScale = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const SizedBox(height: 12),
            ScaleTransition(scale: heroScale, child: const _Hero()),
            const SizedBox(height: 28),
            RevealItem(
              animation: animation,
              index: 2,
              child: Text(
                tr('onboarding.welcome_title'),
                textAlign: TextAlign.center,
                style: PremiumTokens.display(size: 28, letterSpacing: -0.4),
              ),
            ),
            const SizedBox(height: 12),
            RevealItem(
              animation: animation,
              index: 3,
              child: Text(
                tr('onboarding.welcome_subtitle'),
                textAlign: TextAlign.center,
                style:
                    PremiumTokens.body(size: 15, color: pt.grey, height: 1.5),
              ),
            ),
            const SizedBox(height: 32),
            for (final (i, feature) in const [
              (Icons.list_alt_outlined, 'onboarding.welcome_bullet_1'),
              (Icons.verified_outlined, 'onboarding.welcome_bullet_2'),
              (Icons.bolt_outlined, 'onboarding.welcome_bullet_3'),
            ].indexed) ...[
              RevealItem(
                animation: animation,
                index: 4 + i,
                child: _FeatureCard(icon: feature.$1, text: tr(feature.$2)),
              ),
              if (i < 2) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    Widget ring(double size, double alpha) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PremiumTokens.accent.withValues(alpha: alpha),
          ),
        );
    return SizedBox(
      height: 176,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring(176, 0.05),
          ring(138, 0.08),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [PremiumTokens.accent, PremiumTokens.accentDeep],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: PremiumTokens.accentDeep.withValues(alpha: 0.30),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 52,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pt.divider),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Row(
        children: [
          TintedIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: PremiumTokens.body(
                size: 14,
                weight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
