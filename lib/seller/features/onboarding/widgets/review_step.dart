import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../bloc/onboarding_bloc.dart';

class ReviewStep extends StatelessWidget {
  const ReviewStep({super.key, required this.onEditStep});

  final ValueChanged<OnboardingStep> onEditStep;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      builder: (context, state) {
        final pt = PremiumTokens.of(context);
        final draft = state.draft;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ma'lumotlarni tekshiring",
                    style: PremiumTokens.display(size: 26, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Yuborishdan oldin barcha ma'lumotlar to'g'ri ekanligini tekshiring.",
                    style: PremiumTokens.body(
                      size: 14,
                      color: pt.grey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _SummaryCard(
              icon: Icons.business_center_outlined,
              title: tr('onboarding.step_business_type_title'),
              onEdit: () => onEditStep(OnboardingStep.businessType),
              rows: [
                _Row(
                  'Turi',
                  draft.businessType != null
                      ? tr('business_type.${draft.businessType!.code}')
                      : '—',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              icon: Icons.person_outline,
              title: tr('onboarding.step_personal_title'),
              onEdit: () => onEditStep(OnboardingStep.personalInfo),
              rows: [
                _Row(tr('onboarding.legal_name'), draft.legalName ?? '—'),
                _Row(tr('onboarding.contact_phone'), draft.contactPhone ?? '—'),
                if (draft.contactEmail?.isNotEmpty == true)
                  _Row(tr('onboarding.contact_email'), draft.contactEmail!),
                if (draft.telegramUsername?.isNotEmpty == true)
                  _Row(tr('onboarding.telegram'), '@${draft.telegramUsername}'),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              icon: Icons.storefront_outlined,
              title: tr('onboarding.step_shop_title'),
              onEdit: () => onEditStep(OnboardingStep.shopInfo),
              rows: [
                _Row(
                  tr('onboarding.shop_name'),
                  draft.shopNameUz ??
                      draft.shopNameRu ??
                      draft.shopNameEn ??
                      '—',
                ),
                if (draft.shopDescriptionUz?.isNotEmpty == true)
                  _Row(
                    tr('onboarding.shop_description'),
                    draft.shopDescriptionUz!,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _AddressCard(
              address: draft.shopStreetLine,
              landmark: draft.shopLandmark,
              onEdit: () => onEditStep(OnboardingStep.shopAddress),
            ),
          ],
        );
      },
    );
  }
}

class _Row {
  const _Row(this.label, this.value);
  final String label;
  final String value;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.onEdit,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final VoidCallback onEdit;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pt.divider),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Column(
        children: [
          _CardHeader(icon: icon, title: title, onEdit: onEdit),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: pt.divider),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            _RowTile(row: rows[i]),
            if (i != rows.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, color: pt.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.onEdit,
  });

  final IconData icon;
  final String title;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: PremiumTokens.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: PremiumTokens.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: PremiumTokens.body(size: 14, weight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: PremiumTokens.accent,
            visualDensity: VisualDensity.compact,
            tooltip: 'Tahrirlash',
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              row.label,
              style: PremiumTokens.body(
                size: 12,
                color: pt.grey,
                weight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.value,
              style: PremiumTokens.body(
                size: 13,
                weight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.landmark,
    required this.onEdit,
  });

  final String? address;
  final String? landmark;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pt.divider),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.location_on_outlined,
            title: tr('onboarding.step_address_title'),
            onEdit: onEdit,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: pt.divider),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6F4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pt.divider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, color: primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address ?? '—',
                          style: PremiumTokens.body(
                            size: 13,
                            color: pt.dark,
                            weight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        if (landmark?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            landmark!.trim(),
                            style: PremiumTokens.body(
                              size: 12,
                              color: pt.grey,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
