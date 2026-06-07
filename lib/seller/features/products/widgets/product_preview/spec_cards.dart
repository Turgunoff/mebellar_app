import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'product_preview_kit.dart';

/// Grid of length / width / height / weight tiles — only the dimensions that
/// are actually set are rendered (an empty column never shows a "0 sm" tile).
/// Tiles flow two-per-row via a [Wrap] so 1, 2, 3 or 4 set values all lay out
/// cleanly. The whole card is hidden by the caller when nothing is set.
class DimensionsCard extends StatelessWidget {
  const DimensionsCard({
    super.key,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.weightKg,
  });

  final num? lengthCm;
  final num? widthCm;
  final num? heightCm;
  final num? weightKg;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (lengthCm != null && lengthCm! > 0)
        _DimensionTile(
          icon: Iconsax.ruler,
          label: 'Uzunligi',
          value: '${_fmt(lengthCm!)} sm',
        ),
      if (widthCm != null && widthCm! > 0)
        _DimensionTile(
          icon: Iconsax.size,
          label: 'Kengligi',
          value: '${_fmt(widthCm!)} sm',
        ),
      if (heightCm != null && heightCm! > 0)
        _DimensionTile(
          icon: Iconsax.maximize_3,
          label: 'Balandligi',
          value: '${_fmt(heightCm!)} sm',
        ),
      if (weightKg != null && weightKg! > 0)
        _DimensionTile(
          icon: Iconsax.weight,
          label: 'Og\'irligi',
          value: '${_fmt(weightKg!)} kg',
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: "O'lchamlari va og'irligi"),
          const SizedBox(height: 14),
          // Two columns; each tile spans (half - gap) so pairs sit side by side
          // and a lone third/fourth tile wraps to the next line.
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final tile in tiles)
                    SizedBox(width: tileWidth, child: tile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _fmt(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _DimensionTile extends StatelessWidget {
  const _DimensionTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: kGrey),
              const SizedBox(width: 6),
              // Flexible + ellipsis so a long measure label ("Balandligi")
              // never overflows when three tiles share a row on a narrow phone.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: kGrey,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.seller,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kInk,
              letterSpacing: -0.2,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// One furniture piece's dimensions: a title (e.g. "Krovat") and its measures.
class SetDimensionGroup {
  const SetDimensionGroup({required this.piece, required this.measures});

  final String piece;

  /// Ordered `(measureLabel, value)` pairs, e.g. `("Uzunligi", "214 sm")`.
  final List<(String, String)> measures;
}

/// Read-only grouped dimensions for furniture SETS — the per-piece measures
/// (KARAVOT / SHKAF / TRYUMO) the seller entered via the add-product form's
/// grouped DimensionsCard, persisted in `products.attributes`. Mirrors that
/// form layout (piece header + a row of compact value tiles) so the detail
/// view reads the same way the seller authored it, instead of a flat list of
/// nine attribute rows.
class SetDimensionsCard extends StatelessWidget {
  const SetDimensionsCard({super.key, required this.groups});

  final List<SetDimensionGroup> groups;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: "O'lchamlar (sm)"),
          for (var g = 0; g < groups.length; g++) ...[
            SizedBox(height: g == 0 ? 14 : 18),
            Row(
              children: [
                const Icon(Iconsax.ruler, size: 15, color: kGrey),
                const SizedBox(width: 6),
                Text(
                  groups[g].piece,
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < groups[g].measures.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _DimensionTile(
                      icon: Iconsax.size,
                      label: groups[g].measures[i].$1,
                      value: groups[g].measures[i].$2,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Internal product id + creation timestamp — a compact bottom strip.
class IdentifiersCard extends StatelessWidget {
  const IdentifiersCard({
    super.key,
    required this.productId,
    required this.createdAtLabel,
  });

  final String productId;
  final String createdAtLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mahsulot ID',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: kGrey,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  productId,
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Yaratilgan',
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: kGrey,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                createdAtLabel,
                style: const TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
