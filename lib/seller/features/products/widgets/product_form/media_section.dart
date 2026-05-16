import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'form_kit.dart';

/// Horizontal strip of product image thumbnails plus the "add photo" tile.
class MediaSection extends StatelessWidget {
  const MediaSection({
    super.key,
    required this.files,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
  });

  final List<File> files;
  final int maxImages;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final unlimited = maxImages < 0;
    final isFull = !unlimited && files.length >= maxImages;
    final caption = unlimited ? '∞' : '$maxImages';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Mahsulot rasmlari'),
        FormCard(
          child: SizedBox(
            height: 110,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _AddPhotoTile(
                    countLabel: '${files.length}/$caption',
                    enabled: !isFull,
                    onTap: onAdd,
                  ),
                  for (var i = 0; i < files.length; i++) ...[
                    const SizedBox(width: 10),
                    _ImageThumbnail(
                      key: ValueKey('product-image-$i-${files[i].path}'),
                      file: files[i],
                      isPrimary: i == 0,
                      onRemove: () => onRemove(i),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({
    required this.countLabel,
    required this.enabled,
    required this.onTap,
  });

  final String countLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final accent = enabled ? primary : kGreyMid;
    final tint = enabled ? primary.withValues(alpha: 0.08) : kFillSoft;
    return SizedBox(
      width: 110,
      height: 110,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: accent,
            radius: 14,
            strokeWidth: 1.4,
            dashLength: 6,
            gapLength: 4,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.add_square, size: 26, color: accent),
                  const SizedBox(height: 6),
                  Text(
                    "Rasm qo'shish",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: -0.1,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '($countLabel)',
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? primary.withValues(alpha: 0.8)
                          : kGreyMid,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    super.key,
    required this.file,
    required this.isPrimary,
    required this.onRemove,
  });

  final File file;
  final bool isPrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: kFillSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: primary.withValues(alpha: 0.25),
                width: 1.2,
              ),
              image: DecorationImage(
                image: FileImage(file),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (isPrimary)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Asosiy',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: Colors.black26,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kOutline, width: 1),
                  ),
                  child: const Icon(
                    Iconsax.close_square,
                    size: 13,
                    color: kInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}
