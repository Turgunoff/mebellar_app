import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_fonts.dart';
import 'auth_sheet_kit.dart';

/// Step 2 — enter the 6-digit OTP, with a resend countdown.
class OtpStep extends StatelessWidget {
  const OtpStep({
    super.key,
    required this.email,
    required this.controller,
    required this.busy,
    required this.onSubmit,
    required this.remainingLabel,
    required this.canResend,
    required this.onResend,
  });

  final String email;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  final String remainingLabel;
  final bool canResend;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Kodni kiriting', style: authTitleStyle()),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: authSubtitleStyle(),
            children: [
              const TextSpan(text: '6 xonali kod '),
              TextSpan(
                text: email,
                style: authSubtitleStyle().copyWith(
                  color: kTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' manziliga yuborildi.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _PinField(
          controller: controller,
          enabled: !busy,
          onCompleted: onSubmit,
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: 'Tasdiqlash',
          busy: busy,
          onTap: busy ? null : onSubmit,
        ),
        const SizedBox(height: 14),
        Center(
          child: canResend
              ? TextButton(
                  onPressed: onResend,
                  style: TextButton.styleFrom(
                    foregroundColor: kTerracotta,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Kodni qayta yuborish',
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTerracotta,
                    ),
                  ),
                )
              : Text(
                  'Kodni qayta yuborish ($remainingLabel)',
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kTextSecondary,
                  ),
                ),
        ),
      ],
    );
  }
}

class _PinField extends StatefulWidget {
  const _PinField({
    required this.controller,
    required this.enabled,
    required this.onCompleted,
  });

  static const int length = 6;

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onCompleted;

  @override
  State<_PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<_PinField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handle);
    _focus.addListener(_handleFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handle);
    _focus.removeListener(_handleFocus);
    _focus.dispose();
    super.dispose();
  }

  void _handle() {
    setState(() {});
    if (widget.controller.text.length == _PinField.length) {
      widget.onCompleted();
    }
  }

  void _handleFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          // Source-of-truth input. Visually invisible (transparent text + no
          // cursor + no border) but receives keystrokes and IME paste, which
          // a row of N TextFields cannot do reliably.
          Positioned.fill(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: _PinField.length,
              showCursor: false,
              cursorWidth: 0,
              style: const TextStyle(color: Colors.transparent, height: 0.01),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_PinField.length, (i) {
                final filled = i < value.length;
                final isCursor = i == value.length && _focus.hasFocus;
                final ch = filled ? value[i] : '';
                return _PinBox(digit: ch, active: isCursor, filled: filled);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinBox extends StatelessWidget {
  const _PinBox({
    required this.digit,
    required this.active,
    required this.filled,
  });

  final String digit;
  final bool active;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || filled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 48,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? kSurface : kFieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? kTerracotta : kBorder,
          width: highlighted ? 1.6 : 1,
        ),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: kTextPrimary,
        ),
      ),
    );
  }
}
