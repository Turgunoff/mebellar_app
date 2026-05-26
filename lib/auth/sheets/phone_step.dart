import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_fonts.dart';
import 'auth_sheet_kit.dart';
import 'profile_step.dart' show UzPhoneFormatter;

/// Step 1 — collect the Uzbek mobile number that receives the SMS OTP.
///
/// The backend accepts E.164 or a digits-only string; we ship E.164 by
/// prefixing `+998` to the 9-digit national number after stripping spaces.
class PhoneStep extends StatelessWidget {
  const PhoneStep({
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
    final t = AuthTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tizimga kirish', style: authTitleStyle(context)),
        const SizedBox(height: 8),
        Text(
          'Telefon raqamingizni kiriting. SMS orqali tasdiqlash kodi yuboramiz.',
          style: authSubtitleStyle(context),
        ),
        const SizedBox(height: 24),
        const AuthLabel('Telefon raqami'),
        const SizedBox(height: 8),
        Container(
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
                  enabled: !busy,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                    UzPhoneFormatter(),
                  ],
                  onSubmitted: (_) => busy ? null : onSubmit(),
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
