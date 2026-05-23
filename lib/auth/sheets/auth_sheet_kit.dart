import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';

// ── Brand constants (mode-independent) ───────────────────────────────────
// Terracotta and its pressed shade are the same in light and dark — they're
// the app's identity colour, not a surface tint.

const Color kTerracotta = AppColors.terracotta;
const Color kTerracottaDeep = AppColors.terracottaDeep;
const Color kDanger = AppColors.danger;

// ── Adaptive token bag ───────────────────────────────────────────────────
// Anything that is "ink on paper" — surfaces, borders, body text — has
// to flip under dark mode or the sheet looks like a white rectangle
// pasted on a black backdrop. Read via `AuthTokens.of(context)`.

class AuthTokens {
  AuthTokens._(this._isDark);

  factory AuthTokens.of(BuildContext context) =>
      AuthTokens._(Theme.of(context).brightness == Brightness.dark);

  final bool _isDark;

  /// Background of the bottom-sheet card.
  Color get surface =>
      _isDark ? AppColors.darkSurface : AppColors.lightSurface;

  /// Background of input fields and pin cells when empty/idle.
  Color get fieldFill =>
      _isDark ? AppColors.darkImageBg : const Color(0xFFFAFAFA);

  /// Body / headline ink — never pure black so contrast feels softer.
  Color get textPrimary =>
      _isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

  /// Captions, helper text, countdown labels.
  Color get textSecondary =>
      _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  /// 1-px hairlines on inputs and dividers.
  Color get border =>
      _isDark ? AppColors.darkDivider : const Color(0xFFEAEAEA);
}

/// The three stops of the passwordless email-OTP flow.
enum AuthStep { email, otp, profile }

TextStyle authTitleStyle(BuildContext context) => TextStyle(
      fontFamily: AppFonts.seller,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AuthTokens.of(context).textPrimary,
      letterSpacing: -0.3,
      height: 1.2,
    );

TextStyle authSubtitleStyle(BuildContext context) => TextStyle(
      fontFamily: AppFonts.seller,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AuthTokens.of(context).textSecondary,
      height: 1.45,
    );

/// Field label above an [AuthOutlinedField].
class AuthLabel extends StatelessWidget {
  const AuthLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AuthTokens.of(context);
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.seller,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: t.textPrimary,
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
    final t = AuthTokens.of(context);
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
      style: TextStyle(
        fontFamily: AppFonts.seller,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: t.textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: t.fieldFill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintText: hintText,
        hintStyle: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: t.textSecondary,
        ),
        border: border(t.border, 1),
        enabledBorder: border(t.border, 1),
        focusedBorder: border(kTerracotta, 1.6),
        disabledBorder: border(t.border, 1),
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
