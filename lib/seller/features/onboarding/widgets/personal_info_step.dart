import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:mebellar_app/core/i18n/i18n.dart';

import '../bloc/onboarding_bloc.dart';

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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr('onboarding.step_personal_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            tr('onboarding.step_personal_subtitle'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: tr('onboarding.legal_name'),
              hintText: tr('onboarding.legal_name_hint'),
              border: const OutlineInputBorder(),
            ),
            validator: _nameValidator,
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [_phoneMask],
            decoration: InputDecoration(
              labelText: tr('onboarding.contact_phone'),
              hintText: '+998 ## ### ## ##',
              border: const OutlineInputBorder(),
            ),
            validator: _phoneValidator,
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: tr('onboarding.contact_email'),
              border: const OutlineInputBorder(),
            ),
            validator: _emailValidator,
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telegram,
            decoration: InputDecoration(
              labelText: tr('onboarding.telegram_optional'),
              hintText: '@username',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _emit(),
          ),
        ],
      ),
    );
  }
}
