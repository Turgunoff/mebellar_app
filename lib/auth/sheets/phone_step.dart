import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_fonts.dart';
import '../../customer/features/profile/screens/about_screen.dart'
    show StaticContentScreen, StaticContentType;
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

  // Consent gate: the user must accept the privacy policy + terms before the
  // OTP can be requested. Ephemeral per screen open — a fresh login decision.
  bool _agreed = false;

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    _termsTap = TapGestureRecognizer()
      ..onTap =
          () => _openStatic(StaticContentType.terms, 'Foydalanish shartlari');
    _privacyTap = TapGestureRecognizer()
      ..onTap =
          () => _openStatic(StaticContentType.privacy, 'Maxfiylik siyosati');
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  void _toggleAgreed() => setState(() => _agreed = !_agreed);

  bool get _canSubmit => !widget.busy && _agreed;

  void _openStatic(StaticContentType type, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StaticContentScreen(title: title, type: type),
      ),
    );
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
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
                    onSubmitted: (_) => _canSubmit ? widget.onSubmit() : null,
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
        const SizedBox(height: 20),
        _ConsentRow(
          agreed: _agreed,
          enabled: !widget.busy,
          onToggle: _toggleAgreed,
          termsRecognizer: _termsTap,
          privacyRecognizer: _privacyTap,
        ),
        const SizedBox(height: 20),
        AuthPrimaryButton(
          label: 'Kodni olish',
          busy: widget.busy,
          // Stays dimmed + unpressable until the consent box is ticked.
          onTap: _canSubmit ? widget.onSubmit : null,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Privacy + terms consent gate shown above the "Kodni olish" button. Tapping
/// the box or the body text toggles consent; the two highlighted phrases open
/// the matching static document instead.
class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.agreed,
    required this.enabled,
    required this.onToggle,
    required this.termsRecognizer,
    required this.privacyRecognizer,
  });

  final bool agreed;
  final bool enabled;
  final VoidCallback onToggle;
  final TapGestureRecognizer termsRecognizer;
  final TapGestureRecognizer privacyRecognizer;

  @override
  Widget build(BuildContext context) {
    final t = AuthTokens.of(context);
    final base = TextStyle(
      fontFamily: AppFonts.seller,
      fontSize: 12.5,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: t.textSecondary,
    );
    final link = base.copyWith(color: kTerracotta, fontWeight: FontWeight.w600);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ConsentCheckbox(value: agreed, onTap: enabled ? onToggle : null),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onToggle : null,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  style: base,
                  children: [
                    const TextSpan(text: 'Men '),
                    TextSpan(
                      text: 'Maxfiylik siyosati',
                      style: link,
                      recognizer: privacyRecognizer,
                    ),
                    const TextSpan(text: ' va '),
                    TextSpan(
                      text: 'Foydalanish shartlari',
                      style: link,
                      recognizer: termsRecognizer,
                    ),
                    const TextSpan(text: 'ga roziman.'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Square, terracotta-when-checked consent box. A `null` [onTap] leaves it
/// idle (used while a request is in flight).
class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({required this.value, required this.onTap});

  final bool value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AuthTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: value ? kTerracotta : t.fieldFill,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: value ? kTerracotta : t.border,
            width: value ? 0 : 1.4,
          ),
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
