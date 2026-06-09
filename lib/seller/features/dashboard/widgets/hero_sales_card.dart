import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'dashboard_kit.dart';

/// The dashboard's hero: a deep-indigo gradient card with the week's revenue,
/// a trend chip, and an interactive area sparkline with weekday labels.
///
/// The sparkline is drawn with a self-contained painter (Indigo, not the
/// terracotta `RevenueLineChart`) so the seller surface keeps its backoffice
/// colour identity. Tapping a day reveals its value in the top-right readout.
class HeroSalesCard extends StatefulWidget {
  const HeroSalesCard({
    super.key,
    required this.weekRevenue,
    required this.series,
    required this.weekdayLabels,
    required this.deltaPercent,
    this.onTap,
  });

  final num weekRevenue;
  final List<double> series;
  final List<String> weekdayLabels;
  final double deltaPercent;
  final VoidCallback? onTap;

  @override
  State<HeroSalesCard> createState() => _HeroSalesCardState();
}

class _HeroSalesCardState extends State<HeroSalesCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final selectedValue = _selected != null
        ? widget.series[_selected!]
        : widget.weekRevenue;
    final caption = _selected != null
        ? widget.weekdayLabels[_selected!]
        : "Bu hafta savdo";

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4554C4), DashKit.indigoDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: DashKit.indigo.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.wallet_3,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            caption,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              DashKit.money(selectedValue),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'UZS',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _HeroDeltaChip(deltaPercent: widget.deltaPercent),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 78,
              child: LayoutBuilder(
                builder: (context, c) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _select(d.localPosition.dx, c.maxWidth),
                    onPanStart: (d) => _select(d.localPosition.dx, c.maxWidth),
                    onPanUpdate: (d) => _select(d.localPosition.dx, c.maxWidth),
                    onPanEnd: (_) => setState(() => _selected = null),
                    onTapUp: (_) => setState(() => _selected = null),
                    child: CustomPaint(
                      size: Size(c.maxWidth, 78),
                      painter: _SparklinePainter(
                        values: widget.series,
                        selectedIndex: _selected,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < widget.weekdayLabels.length; i++)
                  Text(
                    widget.weekdayLabels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: _selected == i
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _selected == i
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      height: 1.0,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _select(double dx, double width) {
    if (widget.series.isEmpty) return;
    final step = widget.series.length == 1
        ? width
        : width / (widget.series.length - 1);
    final idx = (dx / step).round().clamp(0, widget.series.length - 1);
    if (idx != _selected) setState(() => _selected = idx);
  }
}

class _HeroDeltaChip extends StatelessWidget {
  const _HeroDeltaChip({required this.deltaPercent});

  final double deltaPercent;

  @override
  Widget build(BuildContext context) {
    final up = deltaPercent >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '${up ? '+' : ''}${deltaPercent.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.selectedIndex});

  final List<double> values;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const padTop = 6.0;
    const padBottom = 6.0;
    final h = size.height - padTop - padBottom;
    final w = size.width;

    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : maxV - minV;
    final step = values.length == 1 ? w : w / (values.length - 1);

    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(step * i, padTop + h * (1 - (values[i] - minV) / range)),
    ];

    final line = _smooth(pts);
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(0, 0, w, size.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    final sel = selectedIndex;
    if (sel != null && sel >= 0 && sel < pts.length) {
      final p = pts[sel];
      canvas.drawLine(
        Offset(p.dx, padTop),
        Offset(p.dx, size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        p,
        6,
        Paint()..color = Colors.white.withValues(alpha: 0.3),
      );
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..color = DashKit.indigoDeep
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  Path _smooth(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    if (p.length < 3) {
      for (var i = 1; i < p.length; i++) {
        path.lineTo(p[i].dx, p[i].dy);
      }
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
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.selectedIndex != selectedIndex;
}
