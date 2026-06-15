import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../../../../shared/models/attribute_definition.dart';
import 'form_kit.dart';

/// A grouped "O'lchamlar" card for the set-dimension number attributes
/// (bed/wardrobe/dresser × length/height/width/depth). Furniture-set listings
/// carry up to nine dimensions; rendering them as a flat list of number fields
/// is noisy, so we group them per furniture piece (KARAVOT / SHKAF / TRYUMO)
/// with a labelled header and a compact wrapping row of small fields.
///
/// A dimension attribute is recognised by [isDimensionAttribute]: a `number`
/// type whose label encodes its group + measure as "Piece — measure" (the
/// seed uses that em-dash convention). The piece name before the dash becomes
/// the group header; the measure after it becomes the field label.
class DimensionsCard extends StatelessWidget {
  const DimensionsCard({
    super.key,
    required this.definitions,
    required this.values,
    required this.locale,
    required this.onChanged,
  });

  final List<AttributeDefinition> definitions;
  final Map<String, dynamic> values;
  final String locale;
  final void Function(String key, dynamic value) onChanged;

  @override
  Widget build(BuildContext context) {
    if (definitions.isEmpty) return const SizedBox.shrink();
    final groups = _groupByPiece(definitions, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("O'lchamlar (sm)"),
        FormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var g = 0; g < groups.length; g++) ...[
                if (g > 0) const SizedBox(height: 18),
                _PieceHeader(title: groups[g].piece),
                const SizedBox(height: 10),
                // One row per piece — the (up to 3) measure fields share the
                // width evenly so "uzunligi | balandligi | kengligi" sit side
                // by side.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < groups[g].defs.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _DimensionField(
                          key: ValueKey(groups[g].defs[i].key),
                          label: _measureLabel(groups[g].defs[i], locale),
                          value: values[groups[g].defs[i].key],
                          onChanged: (v) => onChanged(groups[g].defs[i].key, v),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static bool isDimensionAttribute(AttributeDefinition def) {
    return def.dataType == AttributeDataType.number &&
        def.unit == 'sm' &&
        def.labelUz.contains('—');
  }

  List<_PieceGroup> _groupByPiece(
    List<AttributeDefinition> defs,
    String locale,
  ) {
    final order = <String>[];
    final byPiece = <String, List<AttributeDefinition>>{};
    for (final def in defs) {
      final piece = _pieceLabel(def, locale);
      byPiece
          .putIfAbsent(piece, () {
            order.add(piece);
            return [];
          })
          .add(def);
    }
    return [for (final p in order) _PieceGroup(p, byPiece[p]!)];
  }

  static String _pieceLabel(AttributeDefinition def, String locale) {
    final label = def.labelFor(locale);
    final dash = label.indexOf('—');
    return dash == -1 ? label : label.substring(0, dash).trim();
  }

  static String _measureLabel(AttributeDefinition def, String locale) {
    final label = def.labelFor(locale);
    final dash = label.indexOf('—');
    return dash == -1 ? label : label.substring(dash + 1).trim();
  }
}

class _PieceGroup {
  const _PieceGroup(this.piece, this.defs);
  final String piece;
  final List<AttributeDefinition> defs;
}

class _PieceHeader extends StatelessWidget {
  const _PieceHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(Iconsax.ruler, size: 15, color: primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

/// Compact number field for one dimension — stateful so it syncs when the AI
/// fills the value into cubit state after this widget is already mounted.
class _DimensionField extends StatefulWidget {
  const _DimensionField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_DimensionField> createState() => _DimensionFieldState();
}

class _DimensionFieldState extends State<_DimensionField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(covariant _DimensionField old) {
    super.didUpdateWidget(old);
    // Keep the field in sync when the value changes externally (AI fill),
    // but don't fight the user mid-typing.
    final incoming = _format(widget.value);
    if (incoming != _format(old.value) && incoming != _controller.text) {
      _controller.value = TextEditingValue(
        text: incoming,
        selection: TextSelection.collapsed(offset: incoming.length),
      );
    }
  }

  static String _format(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    }
    return v.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          // Wrap rather than truncate so "Balandligi"/"Chuqurligi" stay legible
          // in the narrow 3-across layout (matches the read-only preview card).
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c.grey,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          cursorColor: primary,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: '0',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            filled: true,
            fillColor: c.fillFaint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primary, width: 1.4),
            ),
          ),
          onChanged: (raw) {
            if (raw.isEmpty) {
              widget.onChanged(null);
              return;
            }
            widget.onChanged(num.tryParse(raw.replaceAll(',', '.')));
          },
        ),
      ],
    );
  }
}
