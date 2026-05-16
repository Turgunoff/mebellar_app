import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';

// Local design tokens shared by every shop-settings widget. Plus Jakarta Sans
// is applied to each `Text` explicitly via `AppFonts.seller` so the surface is
// immune to the M3 surface tint the teal seller seed bleeds onto neutrals.
const Color kInk = Color(0xFF1D1D1D);
const Color kGrey = Color(0xFF757575);
const Color kGreyMid = Color(0xFFBDBDBD);
const Color kDivider = Color(0xFFEFEFEF);
const Color kOutline = Color(0xFFE3E3E3);
const Color kFillSoft = Color(0xFFF7F7F7);
const Color kTerracottaTint = Color(0x14C27A5F);

/// Bold section header above each [SettingsCard].
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

/// White, 16px-radius, soft-shadowed card wrapping a settings group.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
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

/// Square terracotta-tinted icon chip used as a leading element in list rows.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: kTerracottaTint,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: AppColors.terracotta),
    );
  }
}

/// Labelled outlined text input with a terracotta focus border. Named
/// `SettingsTextField` (not `FormField`) to avoid shadowing Flutter's
/// built-in `FormField`.
class SettingsTextField extends StatelessWidget {
  const SettingsTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefix,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefix;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
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
          minLines: minLines,
          maxLines: maxLines,
          cursorColor: AppColors.terracotta,
          style: const TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kInk,
            letterSpacing: -0.1,
          ),
          onChanged: onChanged,
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
            prefixText: prefix,
            prefixStyle: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kGreyMid,
            ),
            filled: true,
            fillColor: Colors.white,
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.terracotta,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
