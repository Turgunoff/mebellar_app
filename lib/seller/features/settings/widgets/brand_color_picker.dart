import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

/// Curated palette + custom HSV slider in one bottom sheet. Avoids the
/// `flutter_colorpicker` dependency (Sprint 11 may swap if richer pickers
/// are needed). Returns the chosen colour as a `#RRGGBB` string.
Future<String?> pickBrandColor(BuildContext context, {String? initial}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => _BrandColorSheet(initial: initial),
  );
}

const _swatches = <String>[
  '#5E35B1', '#1976D2', '#0288D1', '#00897B', '#43A047',
  '#FBC02D', '#F4511E', '#D81B60', '#6D4C41', '#546E7A',
  '#000000', '#FFFFFF',
];

class _BrandColorSheet extends StatefulWidget {
  const _BrandColorSheet({this.initial});
  final String? initial;

  @override
  State<_BrandColorSheet> createState() => _BrandColorSheetState();
}

class _BrandColorSheetState extends State<_BrandColorSheet> {
  late String _hex;
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? _swatches.first;
    _hex = initial;
    _hsv = HSVColor.fromColor(_colorFromHex(initial));
  }

  void _setHex(String hex) {
    setState(() {
      _hex = hex;
      _hsv = HSVColor.fromColor(_colorFromHex(hex));
    });
  }

  void _setHsv(HSVColor color) {
    setState(() {
      _hsv = color;
      _hex = _colorToHex(color.toColor());
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(_hex);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('shop_settings.color_picker_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Curated swatches.
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final swatch in _swatches)
                  GestureDetector(
                    onTap: () => _setHex(swatch),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _colorFromHex(swatch),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _hex.toUpperCase() == swatch.toUpperCase()
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: _hex.toUpperCase() == swatch.toUpperCase()
                              ? 2.5
                              : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Hue slider.
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _hex.toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(tr('shop_settings.hue'),
                style: Theme.of(context).textTheme.bodySmall),
            Slider(
              min: 0,
              max: 360,
              value: _hsv.hue,
              onChanged: (v) => _setHsv(_hsv.withHue(v)),
            ),
            Text(tr('shop_settings.saturation'),
                style: Theme.of(context).textTheme.bodySmall),
            Slider(
              min: 0,
              max: 1,
              value: _hsv.saturation,
              onChanged: (v) => _setHsv(_hsv.withSaturation(v)),
            ),
            Text(tr('shop_settings.brightness'),
                style: Theme.of(context).textTheme.bodySmall),
            Slider(
              min: 0,
              max: 1,
              value: _hsv.value,
              onChanged: (v) => _setHsv(_hsv.withValue(v)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr('common.cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _hex),
                    child: Text(tr('common.save')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '').padLeft(6, '0');
  return Color(int.parse('FF$cleaned', radix: 16));
}

String _colorToHex(Color c) {
  // Color.toARGB32() (Flutter 4+) replaces the deprecated `value` getter.
  final argb = c.toARGB32() & 0xFFFFFF;
  return '#${argb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
