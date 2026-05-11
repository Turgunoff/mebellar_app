import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

/// V1 map placeholder. Sprint 5 backlog calls for `flutter_map`/Google Maps;
/// here we draw a static gradient with a draggable pin emoji so the address
/// form can capture an approximate lat/lng without pulling in a paid SDK.
/// Tap inside the box "drops" the pin to a deterministic location relative to
/// the tap fraction; the caller persists those coordinates.
class MapPreview extends StatefulWidget {
  const MapPreview({
    super.key,
    this.lat,
    this.lng,
    this.onChanged,
  });

  final double? lat;
  final double? lng;
  final void Function(double lat, double lng)? onChanged;

  @override
  State<MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<MapPreview> {
  // Anchored in central Tashkent so the placeholder feels plausible.
  static const _baseLat = 41.31;
  static const _baseLng = 69.26;
  static const _spread = 0.06;

  Offset _pin = const Offset(0.5, 0.5);

  @override
  void initState() {
    super.initState();
    if (widget.lat != null && widget.lng != null) {
      final dx = ((widget.lng! - _baseLng) / _spread + 0.5).clamp(0.0, 1.0);
      final dy = ((widget.lat! - _baseLat) / _spread + 0.5).clamp(0.0, 1.0);
      _pin = Offset(dx, dy);
    }
  }

  void _drop(Offset local, Size size) {
    final dx = (local.dx / size.width).clamp(0.0, 1.0);
    final dy = (local.dy / size.height).clamp(0.0, 1.0);
    setState(() => _pin = Offset(dx, dy));
    final lng = _baseLng + (dx - 0.5) * _spread;
    final lat = _baseLat + (dy - 0.5) * _spread;
    widget.onChanged?.call(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer.withValues(alpha: 0.5),
                    scheme.surfaceContainerHigh,
                  ],
                ),
              ),
            ),
            CustomPaint(painter: _GridPainter(scheme.outlineVariant)),
            LayoutBuilder(
              builder: (context, constraints) {
                final size =
                    Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _drop(d.localPosition, size),
                  onPanUpdate: (d) => _drop(d.localPosition, size),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: _pin.dx * size.width - 16,
                        top: _pin.dy * size.height - 32,
                        child: Icon(
                          Icons.location_on,
                          color: scheme.error,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tr('address.tap_map_hint'),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    const step = 24.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color;
}
