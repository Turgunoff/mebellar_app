import 'package:flutter/material.dart';

import '../../core/theme/app_fonts.dart';

// Local design tokens for the auth bottom sheet.
const Color kTerracotta = Color(0xFFC27A5F);
const Color kTerracottaDeep = Color(0xFFB85C38);
const Color kSurface = Color(0xFFFFFFFF);
const Color kFieldFill = Color(0xFFFAFAFA);
const Color kTextPrimary = Color(0xFF1D1D1D);
const Color kTextSecondary = Color(0xFF757575);
const Color kBorder = Color(0xFFEAEAEA);
const Color kDanger = Color(0xFFEF4444);

/// The three stops of the passwordless email-OTP flow.
enum AuthStep { email, otp, profile }

TextStyle authTitleStyle() => const TextStyle(
      fontFamily: AppFonts.seller,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: kTextPrimary,
      letterSpacing: -0.3,
      height: 1.2,
    );

TextStyle authSubtitleStyle() => const TextStyle(
      fontFamily: AppFonts.seller,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: kTextSecondary,
      height: 1.45,
    );

/// Field label above an [AuthOutlinedField].
class AuthLabel extends StatelessWidget {
  const AuthLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.seller,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: kTextPrimary,
        letterSpacing: 0.1,
      ),
    );
  }
}

/// Filled, rounded text field with a terracotta focus border.
class AuthOutlinedField extends StatelessWidget {
  const AuthOutlinedField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontFamily: AppFonts.seller,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: kTextPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: kFieldFill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: kTextSecondary,
        ),
        border: border(kBorder, 1),
        enabledBorder: border(kBorder, 1),
        focusedBorder: border(kTerracotta, 1.6),
        disabledBorder: border(kBorder, 1),
      ),
    );
  }
}

/// Full-width terracotta CTA with a busy spinner state.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return SizedBox(
      height: 54,
      child: Material(
        color: disabled ? kTerracotta.withValues(alpha: 0.55) : kTerracotta,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: kTerracottaDeep.withValues(alpha: 0.3),
          highlightColor: kTerracottaDeep.withValues(alpha: 0.15),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
