import 'package:flutter/material.dart';

import '../constants/product_colors.dart';

/// Compact read-only colour indicator — a swatch dot plus the Uzbek colour
/// name. Resolves [slug] against the shared palette and renders nothing when
/// the slug is empty/null or no longer in the palette. Shared by the cart,
/// checkout and order screens so a chosen colour reads consistently
/// everywhere; each caller supplies its own [labelStyle].
class ProductColorChip extends StatelessWidget {
  const ProductColorChip({
    super.key,
    required this.slug,
    this.labelStyle,
    this.prefix,
    this.swatchSize = 12,
  });

  /// Canonical colour slug (white / black / grey / …). Null or empty hides
  /// the widget entirely.
  final String? slug;

  /// Style for the colour name. Falls back to the ambient text style.
  final TextStyle? labelStyle;

  /// Optional leading word — e.g. `'Rang'` renders "Rang: Oq". When null the
  /// colour name shows on its own.
  final String? prefix;

  final double swatchSize;

  @override
  Widget build(BuildContext context) {
    final raw = slug;
    if (raw == null || raw.isEmpty) return const SizedBox.shrink();
    final option = productColorBySlug(raw);
    if (option == null) return const SizedBox.shrink();
    final label = prefix == null ? option.label : '$prefix: ${option.label}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: swatchSize,
          height: swatchSize,
          decoration: BoxDecoration(
            color: option.swatch,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x1F000000)),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: labelStyle),
      ],
    );
  }
}
