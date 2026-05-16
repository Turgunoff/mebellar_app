import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';

// Local design tokens shared by every product-form widget. Branded
// interactive surfaces still flow through `colorScheme.primary`; these tokens
// only cover neutral ink / borders / fills.
const Color kInk = Color(0xFF1D1D1D);
const Color kGrey = Color(0xFF757575);
const Color kGreyMid = Color(0xFFBDBDBD);
const Color kDivider = Color(0xFFEFEFEF);
const Color kOutline = Color(0xFFE3E3E3);
const Color kFillSoft = Color(0xFFF7F7F7);

/// Section heading above each [FormCard].
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: kInk,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
    this.keyboardType,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
    this.helper,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? minLines;
  final int? maxLines;
  final String? helper;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kOutline, width: 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kGrey,
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
          style: const TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kInk,
            letterSpacing: -0.1,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kGreyMid,
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kGreyMid,
              letterSpacing: 0.2,
            ),
            filled: true,
            fillColor: Colors.white,
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
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: kGrey,
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
    final hasValue = value != null;
    final disabled = onTap == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kGrey,
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
              color: disabled ? kFillSoft : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kOutline, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  leadingIcon,
                  size: 20,
                  color: disabled ? kGreyMid : kGrey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? value! : placeholder,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasValue ? kInk : kGreyMid,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Icon(
                  Iconsax.arrow_down_1,
                  size: 18,
                  color: disabled
                      ? kGreyMid.withValues(alpha: 0.5)
                      : kGreyMid,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
