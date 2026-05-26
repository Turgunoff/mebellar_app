import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_sheet_kit.dart';

/// Step 3 — first-time profile capture for new users.
///
/// Phone is already known from step 1 (and is the auth identity), so the
/// only required field is the full name. Locale ships from the device
/// setting and can be edited later from Profile → Settings.
class ProfileStep extends StatelessWidget {
  const ProfileStep({
    super.key,
    required this.nameController,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tanishing, siz kimsiz?', style: authTitleStyle(context)),
        const SizedBox(height: 8),
        Text(
          'Tizimda sizga murojaat qilishimiz uchun.',
          style: authSubtitleStyle(context),
        ),
        const SizedBox(height: 24),
        const AuthLabel('Ism va familiya'),
        const SizedBox(height: 8),
        AuthOutlinedField(
          controller: nameController,
          hintText: 'Aliyev Akmal',
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          enabled: !busy,
          autofocus: true,
          onSubmitted: (_) => busy ? null : onSubmit(),
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: 'Saqlash va kirish',
          busy: busy,
          onTap: busy ? null : onSubmit,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Formats raw 9-digit national numbers as `XX XXX XX XX`. Lives here so the
/// phone step can import it without adding a new file just for the helper.
class UzPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 9; i++) {
      if (i == 2 || i == 5 || i == 7) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
