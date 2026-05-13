import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../../../../shared/models/business_type.dart';
import '../bloc/onboarding_bloc.dart';

/// In-wizard KYC document picker. File paths live in [OnboardingState] so the
/// wizard's bottom-bar submit button can gate on completeness via canAdvance.
/// Gallery-only by design — the dedicated KYC capture flow is reserved for
/// the post-onboarding verification screen.
class DocumentUploadStep extends StatelessWidget {
  const DocumentUploadStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      buildWhen: (a, b) =>
          a.draft.businessType != b.draft.businessType ||
          a.documentFiles != b.documentFiles,
      builder: (context, state) {
        final pt = PremiumTokens.of(context);
        final type = state.draft.businessType;
        final requirements = type == null
            ? const <_DocumentRequirement>[]
            : _requirementsFor(type);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('onboarding.step_documents_title'),
                    style: PremiumTokens.display(size: 26, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('onboarding.step_documents_subtitle'),
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
            for (var i = 0; i < requirements.length; i++) ...[
              _DocumentUploadCard(
                requirement: requirements[i],
                pickedPath: state.documentFiles[requirements[i].id],
                onPick: () => _pick(context, requirements[i].id),
                onRemove: () => context.read<OnboardingBloc>().add(
                  OnboardingDocumentPicked(documentId: requirements[i].id),
                ),
              ),
              if (i < requirements.length - 1) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Future<void> _pick(BuildContext context, String documentId) async {
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<OnboardingBloc>();
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file == null) return;
      bloc.add(
        OnboardingDocumentPicked(documentId: documentId, filePath: file.path),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Faylni tanlash xatosi: $e')),
      );
    }
  }
}

List<_DocumentRequirement> _requirementsFor(BusinessType type) {
  final passportPair = [
    _DocumentRequirement(
      id: 'passport_front',
      title: tr('onboarding.doc_passport_front_title'),
      subtitle: tr('onboarding.doc_passport_subtitle'),
      icon: Icons.badge_outlined,
    ),
    _DocumentRequirement(
      id: 'passport_back',
      title: tr('onboarding.doc_passport_back_title'),
      subtitle: tr('onboarding.doc_passport_subtitle'),
      icon: Icons.badge_outlined,
    ),
  ];

  return switch (type) {
    BusinessType.individual => passportPair,
    BusinessType.selfEmployed => [
      ...passportPair,
      _DocumentRequirement(
        id: 'certificate',
        title: "O'z-o'zini band qilgan guvohnomasi",
        subtitle: "Davlat ro'yxati",
        icon: Icons.description_outlined,
      ),
    ],
    BusinessType.llc || BusinessType.corporation => [
      ...passportPair,
      const _DocumentRequirement(
        id: 'guvohnoma',
        title: 'Tashkilot guvohnomasi',
        subtitle: "O'zMirror yoki Davlat ro'yxati",
        icon: Icons.assignment_outlined,
      ),
      const _DocumentRequirement(
        id: 'inn',
        title: 'INN (Vergilash shaxsi raqami)',
        subtitle: 'IJM raqami',
        icon: Icons.confirmation_number_outlined,
      ),
    ],
  };
}

class _DocumentRequirement {
  const _DocumentRequirement({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _DocumentUploadCard extends StatelessWidget {
  const _DocumentUploadCard({
    required this.requirement,
    required this.pickedPath,
    required this.onPick,
    required this.onRemove,
  });

  final _DocumentRequirement requirement;
  final String? pickedPath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final hasFile = pickedPath != null;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: hasFile
              ? pt.surface
              : PremiumTokens.accent.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? PremiumTokens.accent
                : PremiumTokens.accent.withValues(alpha: 0.35),
            width: hasFile ? 1.5 : 1.2,
          ),
          boxShadow: hasFile ? PremiumTokens.softShadow : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Thumbnail(filePath: pickedPath, fallbackIcon: requirement.icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      requirement.title,
                      style: PremiumTokens.body(
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (hasFile)
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              tr('onboarding.doc_picked_label'),
                              style: PremiumTokens.body(
                                size: 12,
                                color: Colors.green,
                                weight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '· ${tr('onboarding.doc_replace_cta')}',
                              style: PremiumTokens.body(
                                size: 12,
                                color: pt.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        tr('onboarding.doc_pick_gallery_cta'),
                        style: PremiumTokens.body(
                          size: 12,
                          color: PremiumTokens.accent,
                          weight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (hasFile)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: pt.grey,
                  visualDensity: VisualDensity.compact,
                  tooltip: "O'chirish",
                )
              else
                const Icon(
                  Icons.photo_library_outlined,
                  color: PremiumTokens.accent,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.filePath, required this.fallbackIcon});

  final String? filePath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    const double size = 56;

    if (filePath == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: PremiumTokens.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(fallbackIcon, color: PremiumTokens.accent, size: 26),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(filePath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: pt.imageBg,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, color: pt.grey),
        ),
      ),
    );
  }
}
