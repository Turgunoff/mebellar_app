import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/analytics.dart';

/// Lightweight smooth-line chart drawn with `CustomPainter` — keeps
/// `fl_chart` out of the dependency list for this widget while supporting
/// interactive tap-to-inspect and sparse x-axis date labels.
///
/// When [dates] is supplied the chart becomes interactive:
///   * x-axis labels are rendered along the bottom (sparse, picked so the
///     first/middle/last are always visible),
///   * tapping / dragging shows a vertical guide + a floating tooltip at
///     the top with the date and the formatted value at that point.
class RevenueLineChart extends StatefulWidget {
  const RevenueLineChart({
    super.key,
    required this.values,
    this.dates,
    this.height = 220,
    this.valueFormatter,
    this.unit,
    this.granularity = BucketGranularity.day,
  });

  /// Series values in display order (index 0 = oldest).
  final List<num> values;

  /// Bucket timestamps aligned with [values]. When `null`, the chart
  /// renders without axis labels or tap interaction (pure visual mode).
  final List<DateTime>? dates;

  final double height;

  /// Formats the tooltip's primary value (e.g. UZS amount or count).
  /// Defaults to the integer representation of the bucket value.
  final String Function(num value)? valueFormatter;

  /// Optional unit (e.g. "UZS" / "dona") rendered after the value in
  /// the tooltip — kept separate so the small caps style can be applied.
  final String? unit;

  /// Time-bucket granularity. Controls the format of axis labels ("14:00"
  /// for hourly, "12 May" for daily, "May 26" for monthly) and the
  /// tooltip header.
  final BucketGranularity granularity;

  @override
  State<RevenueLineChart> createState() => _RevenueLineChartState();
}

class _RevenueLineChartState extends State<RevenueLineChart> {
  int? _selectedIndex;

  static final _dayFmt = DateFormat('d MMM', 'uz_UZ');
  static final _monthFmt = DateFormat('MMM yy', 'uz_UZ');
  static final _hourFmt = DateFormat('HH:mm', 'uz_UZ');
  static final _tooltipDayFmt = DateFormat("d MMMM, EEEE", 'uz_UZ');
  static final _tooltipMonthFmt = DateFormat("MMMM yyyy", 'uz_UZ');
  static final _tooltipHourFmt = DateFormat("HH:mm '·' d MMM", 'uz_UZ');

  @override
  void didUpdateWidget(covariant RevenueLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Range / tab switch shrinks (or replaces) the series. A stale
    // `_selectedIndex` from the old series would index out of bounds on
    // the next paint — drop it whenever the underlying series identity
    // changes.
    if (_selectedIndex != null) {
      final newLen = widget.values.length;
      if (newLen == 0 || _selectedIndex! >= newLen) {
        _selectedIndex = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDates = widget.dates != null &&
        widget.dates!.length == widget.values.length;
    // 22px reserved for the x-axis labels strip when present.
    final labelStrip = hasDates ? 22.0 : 0.0;
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, c) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: hasDates
                      ? (d) => _updateFromOffset(d.localPosition, c.maxWidth)
                      : null,
                  onPanStart: hasDates
                      ? (d) => _updateFromOffset(d.localPosition, c.maxWidth)
                      : null,
                  onPanUpdate: hasDates
                      ? (d) => _updateFromOffset(d.localPosition, c.maxWidth)
                      : null,
                  onPanEnd: hasDates
                      ? (_) => setState(() => _selectedIndex = null)
                      : null,
                  onTapCancel: hasDates
                      ? () => setState(() => _selectedIndex = null)
                      : null,
                  child: CustomPaint(
                    painter: _RevenueChartPainter(
                      values: widget.values,
                      dates: widget.dates,
                      granularity: widget.granularity,
                      dayFmt: _dayFmt,
                      monthFmt: _monthFmt,
                      hourFmt: _hourFmt,
                      selectedIndex: _selectedIndex,
                      labelStripHeight: labelStrip,
                    ),
                  ),
                ),
              ),
              if (hasDates &&
                  _selectedIndex != null &&
                  _selectedIndex! < widget.values.length)
                _buildTooltip(c.maxWidth, c.maxHeight - labelStrip),
            ],
          );
        },
      ),
    );
  }

  void _updateFromOffset(Offset local, double width) {
    if (widget.values.isEmpty) return;
    const padX = 4.0;
    final usable = width - padX * 2;
    final stepX = widget.values.length == 1
        ? usable
        : usable / (widget.values.length - 1);
    final rawIndex = ((local.dx - padX) / stepX).round();
    final clamped = rawIndex.clamp(0, widget.values.length - 1);
    if (clamped != _selectedIndex) {
      setState(() => _selectedIndex = clamped);
    }
  }

  Widget _buildTooltip(double width, double chartHeight) {
    final i = _selectedIndex!;
    final value = widget.values[i];
    final date = widget.dates![i];
    final fmt = widget.valueFormatter;
    final formatted = fmt != null ? fmt(value) : value.round().toString();
    final dateLabel = switch (widget.granularity) {
      BucketGranularity.hour => _tooltipHourFmt.format(date.toLocal()),
      BucketGranularity.month => _tooltipMonthFmt.format(date),
      BucketGranularity.day => _tooltipDayFmt.format(date),
    };

    // Position the tooltip near the selected point, but clamp inside the
    // chart so it never clips at the card edges.
    const padX = 4.0;
    final usable = width - padX * 2;
    final stepX =
        widget.values.length == 1 ? usable : usable / (widget.values.length - 1);
    final pointX = padX + stepX * i;
    const tooltipWidth = 160.0;
    var left = pointX - tooltipWidth / 2;
    if (left < 0) left = 0;
    if (left + tooltipWidth > width) left = width - tooltipWidth;

    return Positioned(
      left: left,
      top: 0,
      width: tooltipWidth,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1D),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFBDBDBD),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: formatted,
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                      children: [
                        if (widget.unit != null)
                          TextSpan(
                            text: '  ${widget.unit}',
                            style: TextStyle(
                              fontFamily: AppFonts.seller,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFBDBDBD),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Tooltip arrow (downward-pointing triangle)
            CustomPaint(
              size: const Size(10, 6),
              painter: _TooltipArrowPainter(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  _RevenueChartPainter({
    required this.values,
    required this.dates,
    required this.granularity,
    required this.dayFmt,
    required this.monthFmt,
    required this.hourFmt,
    required this.selectedIndex,
    required this.labelStripHeight,
  });

  final List<num> values;
  final List<DateTime>? dates;
  final BucketGranularity granularity;
  final DateFormat dayFmt;
  final DateFormat monthFmt;
  final DateFormat hourFmt;
  final int? selectedIndex;
  final double labelStripHeight;

  static const _line = AppColors.terracotta;
  static const _fillTop = Color(0x33C27A5F); // terracotta @ 20%
  static const _fillBottom = Color(0x00C27A5F);
  static const _guide = Color(0xFFBDBDBD);
  static const _axisText = Color(0xFF9E9E9E);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const padX = 4.0;
    const padTop = 8.0;
    const padBottom = 8.0;
    final chartH = size.height - labelStripHeight - padTop - padBottom;
    final w = size.width - padX * 2;
    final h = chartH;

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

    // X-axis date labels (sparse).
    if (dates != null && dates!.length == values.length && labelStripHeight > 0) {
      _paintAxisLabels(
        canvas: canvas,
        coords: coords,
        chartBottomY: padTop + h,
        size: size,
      );
    }

    // Selection: vertical guide + accented dot at the chosen point.
    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < coords.length) {
      final p = coords[selected];
      // Dashed vertical guide.
      _paintDashedLine(
        canvas: canvas,
        start: Offset(p.dx, padTop),
        end: Offset(p.dx, padTop + h),
        paint: Paint()
          ..color = _guide
          ..strokeWidth = 1,
      );
      // Outer halo + inner dot.
      canvas.drawCircle(
        p,
        7,
        Paint()..color = _line.withValues(alpha: 0.15),
      );
      canvas.drawCircle(p, 4, Paint()..color = _line);
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _paintAxisLabels({
    required Canvas canvas,
    required List<Offset> coords,
    required double chartBottomY,
    required Size size,
  }) {
    final dates = this.dates!;
    final n = dates.length;
    if (n == 0) return;

    // Pick how many labels to render based on width — aim for ~50px between
    // labels so they don't overlap. Always anchor first + last.
    const minSpacingPx = 56.0;
    final maxLabels =
        (size.width / minSpacingPx).floor().clamp(2, 7);
    final indices = <int>{};
    if (n == 1) {
      indices.add(0);
    } else {
      for (var k = 0; k < maxLabels; k++) {
        final idx = (k * (n - 1) / (maxLabels - 1)).round();
        indices.add(idx);
      }
      indices
        ..add(0)
        ..add(n - 1);
    }

    for (final i in indices) {
      if (i < 0 || i >= coords.length) continue;
      final label = switch (granularity) {
        BucketGranularity.hour => hourFmt.format(dates[i].toLocal()),
        BucketGranularity.month => monthFmt.format(dates[i]),
        BucketGranularity.day => dayFmt.format(dates[i]),
      };
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _axisText,
            height: 1.0,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout();
      var x = coords[i].dx - tp.width / 2;
      if (x < 0) x = 0;
      if (x + tp.width > size.width) x = size.width - tp.width;
      tp.paint(canvas, Offset(x, chartBottomY + 8));
    }
  }

  void _paintDashedLine({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required Paint paint,
  }) {
    const dash = 4.0;
    const gap = 4.0;
    final totalY = end.dy - start.dy;
    var y = start.dy;
    while (y < end.dy) {
      final next = (y + dash).clamp(start.dy, end.dy);
      canvas.drawLine(Offset(start.dx, y), Offset(start.dx, next), paint);
      y = next + gap;
      if (totalY <= 0) break;
    }
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
    return old.values != values ||
        old.dates != dates ||
        old.selectedIndex != selectedIndex ||
        old.granularity != granularity;
  }
}

class _TooltipArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF1D1D1D));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
