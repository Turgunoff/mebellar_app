import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_fonts.dart';
import 'auth_sheet_kit.dart';

/// Step 3 — first-time profile capture (name + phone) for new users.
class ProfileStep extends StatelessWidget {
  const ProfileStep({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
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
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          enabled: !busy,
          autofocus: true,
        ),
        const SizedBox(height: 18),
        const AuthLabel('Telefon raqami'),
        const SizedBox(height: 8),
        _PhoneField(controller: phoneController, enabled: !busy),
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

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = AuthTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
            child: Text(
              '+998',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
          ),
          Container(width: 1, height: 24, color: t.border),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
                UzPhoneFormatter(),
              ],
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: t.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: InputBorder.none,
                hintText: '90 123 45 67',
                hintStyle: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: t.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// Formats raw 9-digit national numbers as `XX XXX XX XX`. Only digits are
/// kept in the underlying value, so callers should still strip non-digits
/// when reading [TextEditingController.text] for the API.
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
