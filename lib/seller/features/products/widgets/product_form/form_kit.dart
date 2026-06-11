import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';

// Local design tokens for the product form. Adaptive neutrals (ink, greys,
// dividers, outline, fills) flip with light/dark — read them from
// `SellerColors.of(context)`: ink→c.ink, grey→c.grey, greyMid→c.greyMid,
// divider→c.divider, outline→c.outline, fillSoft→c.fillFaint. Branded
// interactive surfaces still flow through `colorScheme.primary`.

/// Section heading above each [FormCard].
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: c.ink,
          letterSpacing: -0.2,
          height: 1.2,
        ),
      ),
    );
  }
}

/// White rounded card wrapping a group of form fields.
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Labelled text field used across every form section. Named `FormTextField`
/// (not `FormField`) to avoid shadowing Flutter's built-in `FormField`.
class FormTextField extends StatelessWidget {
  const FormTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.suffix,
    this.suffixWidget,
    this.keyboardType,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
    this.helper,
    this.helperColor,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? suffix;

  /// Interactive suffix (e.g. the currency toggle). Wins over [suffix].
  final Widget? suffixWidget;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? minLines;
  final int? maxLines;
  final String? helper;

  /// Overrides the default grey helper colour (e.g. to echo the brand
  /// primary for the live USD→UZS conversion line).
  final Color? helperColor;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c.outline, width: 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.grey,
              letterSpacing: 0.1,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          minLines: minLines,
          maxLines: maxLines,
          cursorColor: primary,
          onChanged: onChanged,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.ink,
            letterSpacing: -0.1,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: c.greyMid,
            ),
            suffixText: suffixWidget == null ? suffix : null,
            suffixStyle: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.greyMid,
              letterSpacing: 0.2,
            ),
            suffixIcon: suffixWidget == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: suffixWidget,
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            filled: true,
            fillColor: c.surface,
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary, width: 1.4),
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              helper!,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 11,
                fontWeight: helperColor == null
                    ? FontWeight.w500
                    : FontWeight.w600,
                color: helperColor ?? c.grey,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}

/// Tappable read-only field that opens a picker (category, etc.).
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.leadingIcon,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final IconData leadingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final hasValue = value != null;
    final disabled = onTap == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.grey,
              letterSpacing: 0.1,
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: disabled ? c.fillFaint : c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.outline, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  leadingIcon,
                  size: 20,
                  color: disabled ? c.greyMid : c.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? value! : placeholder,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasValue ? c.ink : c.greyMid,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Icon(
                  Iconsax.arrow_down_1,
                  size: 18,
                  color: disabled
                      ? c.greyMid.withValues(alpha: 0.5)
                      : c.greyMid,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
