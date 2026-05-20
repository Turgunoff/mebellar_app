import 'package:flutter/material.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// A single colour entry rendered as a swatch + label pair in the
/// AttributesCard's optional colors row.
class AttributeColorChip {
  const AttributeColorChip({required this.label, required this.swatch});

  final String label;
  final Color swatch;
}

/// Key/value attribute rows inside a single bordered shell.
///
/// Set [colorChips] to surface a final "Ranglar" row that renders colour
/// swatches alongside the labels instead of a comma-separated string — the
/// detail screen relies on this so multi-colour products read visually
/// rather than as plain text.
class AttributesCard extends StatelessWidget {
  const AttributesCard({
    super.key,
    required this.rows,
    this.colorChips = const [],
  });

  final List<(String, String)> rows;
  final List<AttributeColorChip> colorChips;

  @override
  Widget build(BuildContext context) {
    final hasColors = colorChips.isNotEmpty;
    final totalRows = rows.length + (hasColors ? 1 : 0);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: 'Xususiyatlar'),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            _TextRow(label: rows[i].$1, value: rows[i].$2),
            if (i != totalRows - 1)
              const Divider(height: 1, thickness: 1, color: kDivider),
          ],
          if (hasColors) _ColorsRow(chips: colorChips),
        ],
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kGrey,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kInk,
                height: 1.3,
                letterSpacing: -0.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Final row of the card — colour swatches with their localised labels.
class _ColorsRow extends StatelessWidget {
  const _ColorsRow({required this.chips});

  final List<AttributeColorChip> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            flex: 4,
            child: Text(
              'Ranglar',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kGrey,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in chips) _ColorSwatchChip(chip: chip),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatchChip extends StatelessWidget {
  const _ColorSwatchChip({required this.chip});

  final AttributeColorChip chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kOutline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: chip.swatch,
              shape: BoxShape.circle,
              border: Border.all(color: kOutline, width: 1),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            chip.label,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kInk,
              height: 1.0,
              letterSpacing: -0.05,
            ),
          ),
        ],
      ),
    );
  }
}
