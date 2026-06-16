import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../data/ar_scan_repository.dart';

/// Custom locked-down scanning camera — never the OS camera app. Walks the
/// seller through a 3-photo guided capture (front / side / top-back), reviews
/// each shot, collects the three real-world dimensions, then compresses and
/// uploads the JPEGs so the backend can build a true-to-size 3D model.
/// Uzbek-only + seller tokens, matching the rest of the add-product surface.
///
/// Pops `true` once the photos have been submitted (uploaded) so the caller can
/// show the "model is being generated" confirmation.
class ArScanCameraScreen extends StatefulWidget {
  const ArScanCameraScreen({super.key, required this.productId});

  final String productId;

  static const int requiredShots = 3;

  @override
  State<ArScanCameraScreen> createState() => _ArScanCameraScreenState();
}

/// The wizard moves through capturing each of the three shots, a per-photo
/// review after every shot, then the dimensions form, then upload.
enum _WizardStage { capture, review, dimensions }

class _ArScanCameraScreenState extends State<ArScanCameraScreen>
    with WidgetsBindingObserver {
  static const List<String> _guides = [
    '1/3: Old tomondan oling',
    '2/3: Yon tomondan oling',
    '3/3: Tepa/orqa burchakdan oling',
  ];

  CameraController? _controller;
  Future<void>? _initFuture;
  bool _lowLight = false;
  bool _torchOn = false;
  String? _error;

  _WizardStage _stage = _WizardStage.capture;

  /// Confirmed shots (index 0..2). The pending shot lives in [_pendingShot]
  /// until the seller taps "Keyingisi" on the review.
  final List<XFile> _shots = [];
  XFile? _pendingShot;
  bool _capturing = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _setup();
  }

  Future<void> _setup() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // Lock the capture to the back lens at the highest still resolution the
      // device offers — the model is only as good as the source photos.
      final controller = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await controller.initialize();
      _controller = controller;
      await _detectLowLight(controller);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// One-shot ambient-light probe: stream a few frames, average the Y plane,
  /// and flag low light so we can auto-enable the torch before a capture.
  Future<void> _detectLowLight(CameraController controller) async {
    try {
      final samples = <double>[];
      final done = Completer<void>();
      await controller.startImageStream((image) {
        if (samples.length >= 5) return;
        final plane = image.planes.first.bytes;
        if (plane.isNotEmpty) {
          var sum = 0;
          // Sample every 64th byte — enough signal, negligible cost.
          for (var i = 0; i < plane.length; i += 64) {
            sum += plane[i];
          }
          samples.add(sum / (plane.length / 64) / 255.0);
        }
        if (samples.length >= 5 && !done.isCompleted) done.complete();
      });
      await done.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () {},
      );
      await controller.stopImageStream();
      if (samples.isNotEmpty) {
        final avg = samples.reduce((a, b) => a + b) / samples.length;
        _lowLight = avg < 0.25;
      }
    } catch (_) {
      // Probe is best-effort; a failure just means no auto-torch.
    }
  }

  Future<void> _toggleTorch() async {
    final c = _controller;
    if (c == null) return;
    _torchOn = !_torchOn;
    try {
      await c.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      _torchOn = !_torchOn; // revert on failure
    }
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      // Auto-enable the torch when the probe saw a dark scene; flash fires from
      // the torch already, so no separate flash mode is needed.
      if (_lowLight && !_torchOn) {
        _torchOn = true;
        await c.setFlashMode(FlashMode.torch);
      }
      final shot = await c.takePicture();
      if (!mounted) return;
      setState(() {
        _pendingShot = shot;
        _stage = _WizardStage.review;
        _capturing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _error = '$e';
        });
      }
    }
  }

  void _retake() {
    setState(() {
      _pendingShot = null;
      _stage = _WizardStage.capture;
    });
  }

  void _acceptShot() {
    final shot = _pendingShot;
    if (shot == null) return;
    _shots.add(shot);
    _pendingShot = null;
    if (_shots.length >= ArScanCameraScreen.requiredShots) {
      setState(() => _stage = _WizardStage.dimensions);
    } else {
      setState(() => _stage = _WizardStage.capture);
    }
  }

  Future<void> _submit({
    required int heightCm,
    required int widthCm,
    required int lengthCm,
  }) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final photos = <Uint8List>[];
      for (final shot in _shots) {
        photos.add(await _compressUnder1Mb(shot.path));
      }
      await sl<ArScanRepository>().uploadScanPhotos(
        productId: widget.productId,
        photos: photos,
        heightCm: heightCm,
        widthCm: widthCm,
        lengthCm: lengthCm,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Yuklashda xatolik. Qayta urinib ko‘ring.';
        });
      }
    }
  }

  /// Compress a captured JPEG to a sane resolution, then step the quality down
  /// until the result is under 1 MB so the upload + Meshy ingest stay fast.
  static Future<Uint8List> _compressUnder1Mb(String path) async {
    const oneMb = 1024 * 1024;
    for (final quality in [85, 70, 55]) {
      final out = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 1024,
        minHeight: 1024,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (out != null && out.length < oneMb) {
        return Uint8List.fromList(out);
      }
      // Keep the last (lowest-quality) result as the fallback even if it's
      // still over 1 MB — better an oversized upload than a failed scan.
      if (quality == 55 && out != null) {
        return Uint8List.fromList(out);
      }
    }
    // compressWithFile returned null at every step (unreadable / unsupported) —
    // fall back to the raw bytes so the scan can still proceed.
    return Uint8List.fromList(
      await XFile(path).readAsBytes(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (_error != null && _stage != _WizardStage.dimensions) {
            return _ErrorView(message: _error!);
          }
          final c = _controller;
          if (c == null || !c.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.terracotta),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              if (_stage == _WizardStage.review && _pendingShot != null)
                _ShotPreview(path: _pendingShot!.path)
              else
                _FullBleedPreview(controller: c),

              if (_stage == _WizardStage.capture) ...[
                _GuideLabel(text: _guides[_shots.length]),
                _TopBar(
                  torchOn: _torchOn,
                  onClose: () => Navigator.of(context).maybePop(),
                  onToggleTorch: _toggleTorch,
                ),
                _ProgressDots(
                  total: ArScanCameraScreen.requiredShots,
                  done: _shots.length,
                ),
                _ShutterButton(busy: _capturing, onTap: _capture),
              ],

              if (_stage == _WizardStage.review && _pendingShot != null)
                _ReviewControls(
                  isLast: _shots.length == ArScanCameraScreen.requiredShots - 1,
                  onRetake: _retake,
                  onNext: _acceptShot,
                ),

              if (_stage == _WizardStage.dimensions)
                ArDimensionsStep(
                  submitting: _submitting,
                  error: _error,
                  onClose: () => Navigator.of(context).maybePop(),
                  onSubmit: _submit,
                ),

              if (_submitting) const _GeneratingOverlay(),
            ],
          );
        },
      ),
    );
  }
}

/// Top-center capture guide ("1/3: Old tomondan oling", …).
class _GuideLabel extends StatelessWidget {
  const _GuideLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 64),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small 1/3 · 2/3 · 3/3 dot affordance just above the shutter.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.total, required this.done});
  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < done
                    ? AppColors.terracotta
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }
}

/// The capture shutter — a still-photo button (filled circle). Spins while a
/// picture is being taken so a double-tap can't fire two captures.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 40,
      child: Center(
        child: GestureDetector(
          onTap: busy ? null : onTap,
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.terracotta,
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-photo review actions: discard + recapture, or accept + advance.
class _ReviewControls extends StatelessWidget {
  const _ReviewControls({
    required this.isLast,
    required this.onRetake,
    required this.onNext,
  });
  final bool isLast;
  final VoidCallback onRetake;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Qaytadan olish',
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    isLast ? 'O‘lchamlar' : 'Keyingisi',
                    style: const TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a just-captured still full-bleed for review (BoxFit.cover).
class _ShotPreview extends StatelessWidget {
  const _ShotPreview({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

/// Final step: three mandatory real-world dimensions, then "Yuklash".
/// Public so the validation gate can be widget-tested without a live camera.
class ArDimensionsStep extends StatefulWidget {
  const ArDimensionsStep({
    super.key,
    required this.submitting,
    required this.error,
    required this.onClose,
    required this.onSubmit,
  });

  final bool submitting;
  final String? error;
  final VoidCallback onClose;
  final void Function({
    required int heightCm,
    required int widthCm,
    required int lengthCm,
  }) onSubmit;

  @override
  State<ArDimensionsStep> createState() => _ArDimensionsStepState();
}

class _ArDimensionsStepState extends State<ArDimensionsStep> {
  final _height = TextEditingController();
  final _width = TextEditingController();
  final _length = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [_height, _width, _length]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _height.dispose();
    _width.dispose();
    _length.dispose();
    super.dispose();
  }

  int? _parse(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    return (v != null && v > 0) ? v : null;
  }

  bool get _valid =>
      _parse(_height) != null &&
      _parse(_width) != null &&
      _parse(_length) != null;

  void _submit() {
    final h = _parse(_height);
    final w = _parse(_width);
    final l = _parse(_length);
    if (h == null || w == null || l == null) return;
    widget.onSubmit(heightCm: h, widthCm: w, lengthCm: l);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _GlassButton(icon: Icons.close, onTap: widget.onClose),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Mahsulot o‘lchamlari',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Aniq 3D model uchun haqiqiy o‘lchamlarni kiriting.',
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _DimField(label: 'Bo‘yi (sm)', controller: _height),
                    const SizedBox(height: 16),
                    _DimField(label: 'Eni (sm)', controller: _width),
                    const SizedBox(height: 16),
                    _DimField(label: 'Uzunligi (sm)', controller: _length),
                    if (widget.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.error!,
                        style: const TextStyle(
                          fontFamily: AppFonts.seller,
                          color: AppColors.sellerNegative,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_valid && !widget.submitting) ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    disabledBackgroundColor:
                        AppColors.terracotta.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Yuklash',
                    style: TextStyle(
                      fontFamily: AppFonts.seller,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimField extends StatelessWidget {
  const _DimField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.seller,
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontFamily: AppFonts.seller,
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: AppColors.terracotta,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            hintText: '0',
            hintStyle: TextStyle(
              fontFamily: AppFonts.seller,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.terracotta, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.torchOn,
    required this.onClose,
    required this.onToggleTorch,
  });
  final bool torchOn;
  final VoidCallback onClose;
  final VoidCallback onToggleTorch;

  @override
  Widget build(BuildContext context) {
    // Pin to the absolute top — close on the left, torch on the right.
    // Anchoring with Positioned (instead of a full-bleed SafeArea child) stops
    // the Row from centering itself vertically in the expand Stack; SafeArea
    // keeps the controls clear of the notch / Dynamic Island / status bar.
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GlassButton(icon: Icons.close, onTap: onClose),
              _GlassButton(
                icon: torchOn ? Icons.flash_on : Icons.flash_off,
                active: torchOn,
                onTap: onToggleTorch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.terracotta
          : Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Fills the whole screen with the live feed (BoxFit.cover semantics): the
/// preview is centered at its native aspect ratio, then scaled up until it
/// covers the viewport, so no letterbox bars show on any device ratio.
class _FullBleedPreview extends StatelessWidget {
  const _FullBleedPreview({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}

class _GeneratingOverlay extends StatelessWidget {
  const _GeneratingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.terracotta),
          const SizedBox(height: 20),
          const Text(
            '3D model yaratilmoqda. Tasdiqdan so‘ng ilovada ko‘rinadi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.seller,
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera_back, color: Colors.white70, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Kamerani ochib bo‘lmadi. Ruxsatlarni tekshiring.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
