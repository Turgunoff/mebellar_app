import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../../core/i18n/i18n.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../data/add_product_repository.dart';
import 'form_kit.dart';

/// Horizontal strip of product image thumbnails plus the "add photo" tile,
/// with an "AI fill from photos" CTA once at least one image is present.
/// Entries are [FormImage]s — local picks render from file, edit-mode's
/// existing photos render from their remote URL.
class MediaSection extends StatelessWidget {
  const MediaSection({
    super.key,
    required this.images,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
    required this.onAiFill,
    required this.aiBusy,
  });

  final List<FormImage> images;
  final int maxImages;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  /// Tapped to draft the form from the picked photos. Null disables the CTA
  /// (e.g. while another action is in flight).
  final VoidCallback? onAiFill;

  /// True while the AI request is running — shows a spinner, blocks re-tap.
  final bool aiBusy;

  @override
  Widget build(BuildContext context) {
    final unlimited = maxImages < 0;
    final isFull = !unlimited && images.length >= maxImages;
    final caption = unlimited ? '∞' : '$maxImages';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(tr('add_product.section_media')),
        FormCard(
          child: SizedBox(
            height: 110,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _AddPhotoTile(
                    countLabel: '${images.length}/$caption',
                    enabled: !isFull && !aiBusy,
                    onTap: onAdd,
                  ),
                  for (var i = 0; i < images.length; i++) ...[
                    const SizedBox(width: 10),
                    _ImageThumbnail(
                      key: ValueKey(
                        'product-image-$i-'
                        '${images[i].url ?? images[i].file!.path}',
                      ),
                      image: images[i],
                      isPrimary: i == 0,
                      onRemove: () => onRemove(i),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 10),
          _AiFillButton(busy: aiBusy, onTap: onAiFill),
        ],
      ],
    );
  }
}

/// "Fill from photos with AI" CTA. Shows a spinner + disables itself while the
/// request runs. Themed off the seller primary so it reads as an assist, not a
/// primary save action.
class _AiFillButton extends StatelessWidget {
  const _AiFillButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final enabled = !busy && onTap != null;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: enabled ? primary.withValues(alpha: 0.10) : c.fillFaint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // No spinner here — the full-screen AiLoadingOverlay shows the
                // loading state. The button just disables while busy.
                Icon(
                  Iconsax.magicpen,
                  size: 18,
                  color: enabled ? primary : c.greyMid,
                ),
                const SizedBox(width: 8),
                Text(
                  tr('add_product.ai_fill_cta'),
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: enabled ? primary : c.greyMid,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final accent = enabled ? primary : c.greyMid;
    final tint = enabled ? primary.withValues(alpha: 0.08) : c.fillFaint;
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
                    tr('add_product.media_add_photo'),
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
                          : c.greyMid,
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
    required this.image,
    required this.isPrimary,
    required this.onRemove,
  });

  final FormImage image;
  final bool isPrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final provider = image.file != null
        ? FileImage(image.file!) as ImageProvider
        : CachedNetworkImageProvider(image.url!);
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
              color: c.fillFaint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: primary.withValues(alpha: 0.25),
                width: 1.2,
              ),
              image: DecorationImage(image: provider, fit: BoxFit.cover),
            ),
          ),
          if (isPrimary)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tr('add_product.media_primary_badge'),
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
              color: c.surface,
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
                    border: Border.all(color: c.outline, width: 1),
                  ),
                  child: Icon(Iconsax.close_square, size: 13, color: c.ink),
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
