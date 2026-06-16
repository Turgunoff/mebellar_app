import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import 'ar_scan_preview_screen.dart';

/// Custom locked-down scanning camera — never the OS camera app. Records a
/// 1080p clip, auto-stops at exactly 30s, shows a slow-pan guide overlay, and
/// auto-enables the torch in low light. Uzbek-only + seller tokens, matching
/// the rest of the add-product surface.
///
/// Pops `true` once a scan has been submitted (uploaded) so the caller can
/// show the "model is being generated" confirmation.
class ArScanCameraScreen extends StatefulWidget {
  const ArScanCameraScreen({super.key, required this.productId});

  final String productId;

  static const Duration maxDuration = Duration(seconds: 30);

  @override
  State<ArScanCameraScreen> createState() => _ArScanCameraScreenState();
}

class _ArScanCameraScreenState extends State<ArScanCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _recording = false;
  bool _lowLight = false;
  bool _torchOn = false;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  String? _error;

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
      // Constraint 1: lock the capture to 1080p (veryHigh). (Frame rate is
      // governed by the platform at this preset — the `camera` plugin exposes
      // no fps setter, so 30fps is the device default for 1080p video;
      // documented for the native layer if a hard lock is later required.)
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
  /// and flag low light so we can auto-enable the torch. Streaming is stopped
  /// before any recording starts (concurrent stream+record is unreliable).
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

  Future<void> _startRecording() async {
    final c = _controller;
    if (c == null || _recording) return;
    try {
      // Constraint 3: auto-enable the torch when the probe saw a dark scene.
      if (_lowLight && !_torchOn) {
        _torchOn = true;
        await c.setFlashMode(FlashMode.torch);
      }
      await c.startVideoRecording();
      _elapsed = Duration.zero;
      _recording = true;
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _elapsed += const Duration(milliseconds: 100);
        // Constraint 2: hard-stop at exactly 30s.
        if (_elapsed >= ArScanCameraScreen.maxDuration) {
          _stopRecording();
        } else if (mounted) {
          setState(() {});
        }
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _stopRecording() async {
    final c = _controller;
    _ticker?.cancel();
    _ticker = null;
    if (c == null || !_recording) return;
    _recording = false;
    try {
      final file = await c.stopVideoRecording();
      if (_torchOn) {
        _torchOn = false;
        await c.setFlashMode(FlashMode.off);
      }
      if (!mounted) return;
      setState(() {});
      final submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ArScanPreviewScreen(
            productId: widget.productId,
            videoPath: file.path,
          ),
        ),
      );
      // Preview returns true once uploaded → bubble up so the detail screen
      // shows the confirmation; a "retry" (false/null) just stays on camera.
      if (submitted == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
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
    _ticker?.cancel();
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
          final c = _controller;
          if (_error != null) return _ErrorView(message: _error!);
          if (c == null || !c.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.terracotta),
            );
          }
          final ratio = (_elapsed.inMilliseconds /
                  ArScanCameraScreen.maxDuration.inMilliseconds)
              .clamp(0.0, 1.0);
          final remaining = ArScanCameraScreen.maxDuration - _elapsed;
          return Stack(
            fit: StackFit.expand,
            children: [
              _FullBleedPreview(controller: c),
              const _GuideOverlay(),
              _TopBar(
                torchOn: _torchOn,
                onClose: () => Navigator.of(context).maybePop(),
                onToggleTorch: _toggleTorch,
              ),
              if (_recording) _RecordingBadge(remaining: remaining),
              _RecordControls(
                recording: _recording,
                progress: ratio,
                onStart: _startRecording,
                onStop: _stopRecording,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GuideOverlay extends StatelessWidget {
  const _GuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
            borderRadius: BorderRadius.circular(28),
          ),
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Yaxshi yorug‘likni ta’minlang va sekin harakatlaning.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.seller,
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
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

/// Top-center recording pill: a terracotta dot + remaining time. Lives in the
/// top safe area between the close/torch buttons, so it never overlaps the
/// centered guide bubble or the bottom record cluster.
class _RecordingBadge extends StatelessWidget {
  const _RecordingBadge({required this.remaining});
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final secs = remaining.inSeconds
        .clamp(0, ArScanCameraScreen.maxDuration.inSeconds);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.terracotta,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '0:${secs.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontFamily: AppFonts.seller,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
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

class _RecordControls extends StatelessWidget {
  const _RecordControls({
    required this.recording,
    required this.progress,
    required this.onStart,
    required this.onStop,
  });
  final bool recording;
  final double progress;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 40,
      child: Center(
        child: SizedBox(
          width: 92,
          height: 92,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Terracotta ring fills as the 30s clip elapses — the sole
              // progress affordance, wrapping the shutter so it can't collide
              // with the guide bubble in the middle of the frame.
              if (recording)
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.terracotta),
                  ),
                ),
              GestureDetector(
                onTap: recording ? onStop : onStart,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: recording ? 28 : 58,
                      height: recording ? 28 : 58,
                      decoration: BoxDecoration(
                        color: AppColors.terracotta,
                        borderRadius: BorderRadius.circular(recording ? 8 : 99),
                      ),
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
            const Icon(Icons.videocam_off, color: Colors.white70, size: 40),
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
