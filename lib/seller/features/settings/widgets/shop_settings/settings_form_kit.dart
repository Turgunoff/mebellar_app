import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';

// Every colour in the shop-settings widgets comes from `SellerColors.of(context)`
// so the surface flips with the theme — including the indigo accent disc, which
// uses `c.primarySoft` / `c.onPrimarySoft` (soft tint in light, low-luminance
// wash in dark) instead of a fixed light tint that would glow as an island on a
// dark card. Plus Jakarta Sans is applied to each `Text` explicitly via
// `AppFonts.seller` so the surface is immune to the M3 surface tint the seller
// seed bleeds onto neutrals.

/// Bold section header above each [SettingsCard].
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

/// White, 16px-radius, soft-shadowed card wrapping a settings group.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
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

/// Square indigo-tinted icon chip used as a leading element in list rows.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: c.onPrimarySoft),
    );
  }
}

/// Labelled outlined text input with an indigo focus border. Named
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
    this.cornerAction,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefix;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  /// Optional widget pinned to the field's top-right corner (e.g. the AI
  /// magic-wand button on the description field). The text area is padded on
  /// the right so content never slides under it.
  final Widget? cornerAction;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
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
        Stack(
          children: [
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              minLines: minLines,
              maxLines: maxLines,
              cursorColor: AppColors.sellerPrimary,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.ink,
                letterSpacing: -0.1,
              ),
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.only(
                  left: 14,
                  top: 14,
                  bottom: 14,
                  // Keep text clear of the corner action when present.
                  right: cornerAction != null ? 46 : 14,
                ),
                hintText: hint,
            hintStyle: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: c.greyMid,
            ),
            prefixText: prefix,
            prefixStyle: TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.greyMid,
            ),
            filled: true,
            fillColor: c.surface,
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.sellerPrimary,
                width: 1.4,
              ),
            ),
              ),
            ),
            if (cornerAction != null)
              Positioned(top: 6, right: 6, child: cornerAction!),
          ],
        ),
      ],
    );
  }
}
