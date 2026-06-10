import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../bloc/onboarding_bloc.dart';
import 'onboarding_kit.dart';

class PersonalInfoStep extends StatefulWidget {
  const PersonalInfoStep({super.key, required this.formKey});

  final GlobalKey<FormState> formKey;

  @override
  State<PersonalInfoStep> createState() => _PersonalInfoStepState();
}

class _PersonalInfoStepState extends State<PersonalInfoStep> {
  static final RegExp _emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$');

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _telegram;
  late final MaskTextInputFormatter _phoneMask;

  @override
  void initState() {
    super.initState();
    final draft = context.read<OnboardingBloc>().state.draft;
    _name = TextEditingController(text: draft.legalName ?? '');
    _phoneMask = MaskTextInputFormatter(
      mask: '+998 ## ### ## ##',
      filter: {'#': RegExp(r'\d')},
      initialText: draft.contactPhone ?? '',
    );
    _phone = TextEditingController(text: _phoneMask.getMaskedText());
    _email = TextEditingController(text: draft.contactEmail ?? '');
    _telegram = TextEditingController(text: draft.telegramUsername ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _telegram.dispose();
    super.dispose();
  }

  void _emit() {
    context.read<OnboardingBloc>().add(
      OnboardingPersonalInfoChanged(
        legalName: _name.text,
        contactPhone: _phone.text,
        contactEmail: _email.text,
        telegramUsername: _telegram.text,
      ),
    );
  }

  String? _nameValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 3) return 'Kamida 3 ta belgi kiriting';
    return null;
  }

  String? _phoneValidator(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\+998 \d{2} \d{3} \d{2} \d{2}$').hasMatch(text)) {
      return 'Telefon raqam +998 ## ### ## ## ko\'rinishida bo\'lishi kerak';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email kiriting';
    if (!_emailRegex.hasMatch(text)) return 'Email manzil noto\'g\'ri';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: StepReveal(
        step: OnboardingStep.personalInfo,
        children: [
          StepHeader(
            title: tr('onboarding.step_personal_title'),
            subtitle: tr('onboarding.step_personal_subtitle'),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: onboardingFieldDecoration(
              context,
              label: tr('onboarding.legal_name'),
              hint: tr('onboarding.legal_name_hint'),
              icon: Icons.person_outline_rounded,
            ),
            validator: _nameValidator,
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [_phoneMask],
            decoration: onboardingFieldDecoration(
              context,
              label: tr('onboarding.contact_phone'),
              hint: '+998 ## ### ## ##',
              icon: Icons.phone_outlined,
            ),
            validator: _phoneValidator,
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: onboardingFieldDecoration(
              context,
              label: tr('onboarding.contact_email'),
              icon: Icons.mail_outline_rounded,
            ),
            validator: _emailValidator,
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _telegram,
            decoration: onboardingFieldDecoration(
              context,
              label: tr('onboarding.telegram_optional'),
              hint: '@username',
              icon: Icons.send_outlined,
            ),
            onChanged: (_) => _emit(),
          ),
        ],
      ),
    );
  }
}
