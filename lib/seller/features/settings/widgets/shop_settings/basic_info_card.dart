import 'package:flutter/material.dart';
import 'package:woody_app/core/i18n/i18n.dart';

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
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController telegramController;
  final VoidCallback onChanged;

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
                onChanged: (_) => onChanged(),
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
