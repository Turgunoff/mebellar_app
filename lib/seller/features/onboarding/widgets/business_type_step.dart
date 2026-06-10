import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../../../../shared/models/business_type.dart';
import '../bloc/onboarding_bloc.dart';
import 'onboarding_kit.dart';

class BusinessTypeStep extends StatelessWidget {
  const BusinessTypeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      buildWhen: (a, b) => a.draft.businessType != b.draft.businessType,
      builder: (context, state) {
        return StepReveal(
          step: OnboardingStep.businessType,
          children: [
            StepHeader(
              title: tr('onboarding.step_business_type_title'),
              subtitle: tr('onboarding.step_business_type_subtitle'),
            ),
            const SizedBox(height: 24),
            for (final (i, type) in BusinessType.values.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              _BusinessTypeCard(
                type: type,
                selected: state.draft.businessType == type,
                // Only individual sellers are accepted at launch; the other
                // legal forms stay visible as a roadmap but can't be picked.
                enabled: type == BusinessType.individual,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BusinessTypeCard extends StatelessWidget {
  const _BusinessTypeCard({
    required this.type,
    required this.selected,
    required this.enabled,
  });

  final BusinessType type;
  final bool selected;
  final bool enabled;

  IconData get _icon => switch (type) {
        BusinessType.individual => Icons.person_outline_rounded,
        BusinessType.selfEmployed => Icons.badge_outlined,
        BusinessType.llc => Icons.business_outlined,
        BusinessType.corporation => Icons.domain_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? PremiumTokens.accent.withValues(alpha: 0.06)
              : pt.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? PremiumTokens.accent : pt.divider,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? PremiumTokens.softShadow : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled
                ? () => context
                    .read<OnboardingBloc>()
                    .add(OnboardingBusinessTypeChanged(type))
                : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TintedIcon(icon: _icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                tr('business_type.${type.code}'),
                                style: PremiumTokens.body(
                                  size: 14.5,
                                  weight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (!enabled) ...[
                              const SizedBox(width: 8),
                              const _ComingSoonBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          enabled
                              ? tr('business_type.${type.code}_hint')
                              : tr('business_type.coming_soon_hint'),
                          style: PremiumTokens.body(
                            size: 12.5,
                            color: pt.grey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RadioDot(selected: selected, enabled: enabled),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: PremiumTokens.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tr('business_type.coming_soon_badge'),
        style: PremiumTokens.body(
          size: 10.5,
          weight: FontWeight.w700,
          color: PremiumTokens.accent,
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? PremiumTokens.accent : pt.greyLight,
          width: selected ? 6.5 : 2,
        ),
      ),
    );
  }
}
