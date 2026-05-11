import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/onboarding_bloc.dart';

class VerifyChoiceStep extends StatelessWidget {
  const VerifyChoiceStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      buildWhen: (a, b) => a.draft.verifyNow != b.draft.verifyNow,
      builder: (context, state) {
        final scheme = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr('onboarding.step_verify_title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              tr('onboarding.step_verify_subtitle'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _ChoiceCard(
              selected: state.draft.verifyNow,
              icon: Icons.verified_outlined,
              title: tr('onboarding.verify_now_title'),
              subtitle: tr('onboarding.verify_now_subtitle'),
              accent: scheme.primary,
              onTap: () => context
                  .read<OnboardingBloc>()
                  .add(const OnboardingVerifyChoiceChanged(true)),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              selected: !state.draft.verifyNow,
              icon: Icons.schedule_outlined,
              title: tr('onboarding.verify_later_title'),
              subtitle: tr('onboarding.verify_later_subtitle'),
              accent: scheme.tertiary,
              onTap: () => context
                  .read<OnboardingBloc>()
                  .add(const OnboardingVerifyChoiceChanged(false)),
            ),
          ],
        );
      },
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? accent : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: accent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
