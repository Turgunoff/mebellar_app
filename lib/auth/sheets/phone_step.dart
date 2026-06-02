import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_fonts.dart';
import 'auth_sheet_kit.dart';
import 'profile_step.dart' show UzPhoneFormatter;

/// Step 1 — collect the Uzbek mobile number that receives the SMS OTP.
///
/// The backend accepts E.164 or a digits-only string; we ship E.164 by
/// prefixing `+998` to the 9-digit national number after stripping spaces.
class PhoneStep extends StatefulWidget {
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
  State<PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<PhoneStep> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AuthTokens.of(context);
    final focused = _focus.hasFocus;
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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focus.requestFocus(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: t.fieldFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: focused ? kTerracotta : t.border,
                width: focused ? 1.6 : 1,
              ),
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
                Container(width: 1, height: 22, color: t.border),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: !widget.busy,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    cursorColor: kTerracotta,
                    autofillHints: const [
                      AutofillHints.telephoneNumberNational,
                    ],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                      UzPhoneFormatter(),
                    ],
                    onSubmitted: (_) => widget.busy ? null : widget.onSubmit(),
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                      color: t.textPrimary,
                    ),
                    // `filled: false` and the explicit no-op borders below
                    // override the global InputDecorationTheme (filled:true +
                    // fillColor). Without them the field paints its OWN tinted
                    // rounded box inside this container — the two-tone look.
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: '90 123 45 67',
                      hintStyle: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.4,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: 'Kodni olish',
          busy: widget.busy,
          onTap: widget.busy ? null : widget.onSubmit,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
