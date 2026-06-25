import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/i18n/i18n.dart';

/// Telegram-style crop step: the picked image sits under a fixed frame
/// ([aspectRatio], optionally a circle mask) and the user pinch-zooms / pans
/// until the part they want fills the frame. Returns the cropped file
/// (PNG, capped at [maxOutputWidth]) or null when cancelled.
Future<File?> openImageCropScreen(
  BuildContext context, {
  required File file,
  required double aspectRatio,
  bool circle = false,
  int maxOutputWidth = 1600,
}) {
  return Navigator.of(context, rootNavigator: true).push<File?>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/image-crop'),
      fullscreenDialog: true,
      builder: (_) => _ImageCropScreen(
        file: file,
        aspectRatio: aspectRatio,
        circle: circle,
        maxOutputWidth: maxOutputWidth,
      ),
    ),
  );
}

class _ImageCropScreen extends StatefulWidget {
  const _ImageCropScreen({
    required this.file,
    required this.aspectRatio,
    required this.circle,
    required this.maxOutputWidth,
  });

  final File file;
  final double aspectRatio;
  final bool circle;
  final int maxOutputWidth;

  @override
  State<_ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<_ImageCropScreen> {
  final TransformationController _transform = TransformationController();
  ui.Image? _image;
  bool _saving = false;
  Size? _initializedFor;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final bytes = await widget.file.readAsBytes();
    final image = await decodeImageFromList(bytes);
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => _image = image);
  }

  @override
  void dispose() {
    _transform.dispose();
    _image?.dispose();
    super.dispose();
  }

  /// Minimum scale that keeps the image covering the whole crop frame.
  double _coverScale(Size crop) {
    final img = _image!;
    return math.max(crop.width / img.width, crop.height / img.height);
  }

  /// Cover-fit + centre the image inside the crop viewport, once per layout.
  void _initTransform(Size crop) {
    if (_initializedFor == crop || _image == null) return;
    _initializedFor = crop;
    final img = _image!;
    final s = _coverScale(crop);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        (crop.width - img.width * s) / 2,
        (crop.height - img.height * s) / 2,
        0,
        1,
      )
      ..scaleByDouble(s, s, s, 1);
  }

  Future<void> _confirm(Size crop) async {
    final img = _image;
    if (img == null || _saving) return;
    setState(() => _saving = true);
    try {
      final m = _transform.value;
      final s = m.storage[0];
      final tx = m.storage[12];
      final ty = m.storage[13];

      // Viewport (0,0)..(cropW,cropH) mapped back into image pixel space.
      var srcW = crop.width / s;
      var srcH = crop.height / s;
      var srcL = -tx / s;
      var srcT = -ty / s;
      srcW = srcW.clamp(1.0, img.width.toDouble());
      srcH = srcH.clamp(1.0, img.height.toDouble());
      srcL = srcL.clamp(0.0, img.width - srcW);
      srcT = srcT.clamp(0.0, img.height - srcH);
      final src = Rect.fromLTWH(srcL, srcT, srcW, srcH);

      final outW = math.min(srcW, widget.maxOutputWidth.toDouble());
      final outH = outW * (srcH / srcW);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        img,
        src,
        Rect.fromLTWH(0, 0, outW, outH),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final out = await picture.toImage(outW.round(), outH.round());
      picture.dispose();
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      out.dispose();
      if (data == null) throw StateError('crop encode failed');

      final cropped = File('${widget.file.path}.crop.png');
      await cropped.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(cropped);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('common.image_crop_failed'))),
      );
    }
  }

  Size _cropSizeFor(BoxConstraints box) {
    var w = box.maxWidth - 48;
    var h = w / widget.aspectRatio;
    final maxH = box.maxHeight * 0.55;
    if (h > maxH) {
      h = maxH;
      w = h * widget.aspectRatio;
    }
    return Size(w, h);
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      body: img == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            )
          : LayoutBuilder(
              builder: (context, box) {
                final crop = _cropSizeFor(box);
                _initTransform(crop);
                // Frame sits slightly above centre to clear the bottom bar.
                final cropRect = Rect.fromCenter(
                  center: Offset(
                    box.maxWidth / 2,
                    (box.maxHeight - 120) / 2 + 24,
                  ),
                  width: crop.width,
                  height: crop.height,
                );
                return Stack(
                  children: [
                    Positioned.fromRect(
                      rect: cropRect,
                      child: InteractiveViewer(
                        transformationController: _transform,
                        constrained: false,
                        clipBehavior: Clip.none,
                        minScale: _coverScale(crop),
                        maxScale: _coverScale(crop) * 8,
                        boundaryMargin: EdgeInsets.zero,
                        child: SizedBox(
                          width: img.width.toDouble(),
                          height: img.height.toDouble(),
                          child: Image.file(
                            widget.file,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(box.maxWidth, box.maxHeight),
                        painter: _CropOverlayPainter(
                          cropRect: cropRect,
                          circle: widget.circle,
                        ),
                      ),
                    ),
                    _TopBar(onClose: () => Navigator.of(context).pop()),
                    _BottomBar(
                      saving: _saving,
                      onCancel: () => Navigator.of(context).pop(),
                      onConfirm: () => _confirm(crop),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      right: 16,
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.14),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onClose,
              child: const SizedBox(
                width: 40,
                height: 40,
                child:
                    Icon(Iconsax.close_square, size: 20, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('common.image_crop_title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.saving,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom + 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('common.image_crop_hint'),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: saving ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(tr('common.cancel')),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: saving ? null : onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            tr('common.done'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dims everything outside the crop frame and draws the frame border plus a
/// rule-of-thirds grid inside it.
class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.cropRect, required this.circle});

  final Rect cropRect;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = circle
        ? (Path()..addOval(cropRect))
        : (Path()
          ..addRRect(
            RRect.fromRectAndRadius(cropRect, const Radius.circular(16)),
          ));
    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      hole,
    );
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );

    canvas.drawPath(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.white.withValues(alpha: 0.28);
    canvas.save();
    canvas.clipPath(hole);
    for (var i = 1; i <= 2; i++) {
      final dx = cropRect.left + cropRect.width * i / 3;
      final dy = cropRect.top + cropRect.height * i / 3;
      canvas.drawLine(
        Offset(dx, cropRect.top),
        Offset(dx, cropRect.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(cropRect.left, dy),
        Offset(cropRect.right, dy),
        grid,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.cropRect != cropRect || old.circle != circle;
}
