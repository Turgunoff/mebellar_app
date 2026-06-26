import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../../core/theme/app_colors.dart';
import 'settings_form_kit.dart';

/// Shop name, description and contact-channel fields.
class BasicInfoCard extends StatelessWidget {
  const BasicInfoCard({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.phoneController,
    required this.emailController,
    required this.telegramController,
    required this.onChanged,
    required this.onDescriptionChanged,
    required this.onAiDescribe,
    required this.aiBusy,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController telegramController;
  final VoidCallback onChanged;

  /// Description edits reset the AI variety chain + reseed the hint, so they
  /// have their own callback distinct from the shared [onChanged].
  final VoidCallback onDescriptionChanged;
  final VoidCallback onAiDescribe;
  final bool aiBusy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(tr('shop_settings.basics_title')),
        SettingsCard(
          child: Column(
            children: [
              SettingsTextField(
                controller: nameController,
                label: tr('onboarding.shop_name'),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 14),
              SettingsTextField(
                controller: descriptionController,
                label: tr('onboarding.shop_description'),
                minLines: 3,
                maxLines: 5,
                onChanged: (_) => onDescriptionChanged(),
                cornerAction: _AiDescribeButton(
                  busy: aiBusy,
                  onTap: onAiDescribe,
                ),
              ),
              const SizedBox(height: 14),
              SettingsTextField(
                controller: phoneController,
                label: tr('onboarding.contact_phone'),
                keyboardType: TextInputType.phone,
                hint: '+998 90 111 22 33',
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 14),
              SettingsTextField(
                controller: emailController,
                label: tr('onboarding.contact_email'),
                keyboardType: TextInputType.emailAddress,
                hint: 'info@example.uz',
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 14),
              SettingsTextField(
                controller: telegramController,
                label: tr('onboarding.telegram'),
                hint: 'username',
                prefix: '@',
                onChanged: (_) => onChanged(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// AI magic-wand pinned to the description field's corner. Tapping asks the
/// backend to write (or rewrite) the description; a spinner replaces the icon
/// while it generates and re-taps yield fresh variants.
class _AiDescribeButton extends StatelessWidget {
  const _AiDescribeButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('shop_settings.ai_describe_tooltip'),
      child: Material(
        color: AppColors.sellerPrimary.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.sellerPrimary,
                    ),
                  )
                : const Icon(
                    Iconsax.magicpen,
                    size: 18,
                    color: AppColors.sellerPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}
