import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Lightweight smooth-line chart drawn with `CustomPainter` — keeps
/// `fl_chart` out of the dependency list while the analytics screen
/// only needs one chart. Renders a terracotta curve with a gradient
/// fill underneath; no axis lines or grid for a clean SaaS look.
class RevenueLineChart extends StatelessWidget {
  const RevenueLineChart({
    super.key,
    required this.values,
    this.height = 220,
  });

  /// Daily revenue amounts in display order (index 0 = oldest).
  final List<num> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _RevenueChartPainter(values: values),
      ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  _RevenueChartPainter({required this.values});

  final List<num> values;

  static const _line = AppColors.terracotta;
  static const _fillTop = Color(0x33C27A5F); // terracotta @ 20%
  static const _fillBottom = Color(0x00C27A5F);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    // Padding keeps the stroke from clipping at the card's edges.
    const padX = 4.0;
    const padTop = 8.0;
    const padBottom = 8.0;
    final w = size.width - padX * 2;
    final h = size.height - padTop - padBottom;

    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final minV = values.reduce((a, b) => a < b ? a : b).toDouble();
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : maxV - minV;

    final stepX = values.length == 1 ? w : w / (values.length - 1);
    final coords = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final ratio = (values[i].toDouble() - minV) / range;
      final x = padX + stepX * i;
      final y = padTop + h * (1 - ratio);
      coords.add(Offset(x, y));
    }

    final linePath = _smoothPath(coords);

    // Gradient fill underneath the curve.
    final fillPath = Path.from(linePath)
      ..lineTo(coords.last.dx, padTop + h)
      ..lineTo(coords.first.dx, padTop + h)
      ..close();
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_fillTop, _fillBottom],
      ).createShader(Rect.fromLTWH(0, padTop, size.width, h));
    canvas.drawPath(fillPath, fillPaint);

    // Curve.
    canvas.drawPath(
      linePath,
      Paint()
        ..color = _line
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  /// Catmull-Rom → cubic-Bezier conversion (tension 0.5). Produces a
  /// continuous, naturally smoothed curve through every point without
  /// the overshoot artifacts a naïve `quadraticBezierTo` produces.
  Path _smoothPath(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    if (p.length == 1) return path;
    if (p.length == 2) {
      path.lineTo(p[1].dx, p[1].dy);
      return path;
    }
    for (var i = 0; i < p.length - 1; i++) {
      final p0 = i > 0 ? p[i - 1] : p[i];
      final p1 = p[i];
      final p2 = p[i + 1];
      final p3 = i < p.length - 2 ? p[i + 2] : p2;

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter old) {
    return old.values != values;
  }
}
