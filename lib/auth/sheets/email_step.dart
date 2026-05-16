import 'package:flutter/material.dart';

import 'auth_sheet_kit.dart';

/// Step 1 — collect the email address that the OTP will be sent to.
class EmailStep extends StatelessWidget {
  const EmailStep({
    super.key,
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tizimga kirish', style: authTitleStyle()),
        const SizedBox(height: 8),
        Text(
          'Email manzilingizni kiriting. Tasdiqlash kodini yuboramiz.',
          style: authSubtitleStyle(),
        ),
        const SizedBox(height: 24),
        const AuthLabel('Email'),
        const SizedBox(height: 8),
        AuthOutlinedField(
          controller: controller,
          hintText: 'siz@misol.uz',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          enabled: !busy,
          autofocus: true,
          onSubmitted: (_) => busy ? null : onSubmit(),
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: 'Kodni olish',
          busy: busy,
          onTap: busy ? null : onSubmit,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
