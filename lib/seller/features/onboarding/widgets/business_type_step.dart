// ignore_for_file: deprecated_member_use
// Sprint 11 will migrate to RadioGroup; deprecated API works for V1.
import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/business_type.dart';
import '../bloc/onboarding_bloc.dart';

class BusinessTypeStep extends StatelessWidget {
  const BusinessTypeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      buildWhen: (a, b) => a.draft.businessType != b.draft.businessType,
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr('onboarding.step_business_type_title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              tr('onboarding.step_business_type_subtitle'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final type in BusinessType.values)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: state.draft.businessType == type
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: state.draft.businessType == type ? 1.5 : 1,
                  ),
                ),
                child: RadioListTile<BusinessType>(
                  value: type,
                  groupValue: state.draft.businessType,
                  onChanged: (v) {
                    if (v == null) return;
                    context
                        .read<OnboardingBloc>()
                        .add(OnboardingBusinessTypeChanged(v));
                  },
                  title: Text(tr('business_type.${type.code}')),
                  subtitle: Text(tr('business_type.${type.code}_hint')),
                  isThreeLine: true,
                ),
              ),
          ],
        );
      },
    );
  }
}
