import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/theme/app_fonts.dart';

/// Graceful 2D fallback for the buyer AR viewer on devices that can't run
/// ARCore (Scene Viewer would otherwise bounce the user to the Play Store for
/// a "Google Play Services for AR" build that won't run here).
///
/// Shows a full-screen live camera feed with the product's main photo floated
/// on top. The photo is freely draggable, pinch-to-zoom and two-finger
/// rotatable via a [Matrix4] composed from the scale gesture — so the buyer can
/// still eyeball the piece against their room, manually. No AR, no store
/// redirect, no native ARCore dependency.
class Fallback2DCameraScreen extends StatefulWidget {
  const Fallback2DCameraScreen({
    super.key,
    required this.imageUrl,
    required this.productName,
  });

  /// The product's main image (a normal photo). May be null/empty — then a
  /// neutral placeholder card is floated instead.
  final String? imageUrl;
  final String productName;

  @override
  State<Fallback2DCameraScreen> createState() => _Fallback2DCameraScreenState();
}

class _Fallback2DCameraScreenState extends State<Fallback2DCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;

  /// Fatal camera-setup error (no permission / no camera) — takes over the
  /// screen. [_permanentlyDenied] adds an "open settings" affordance.
  String? _error;
  bool _permanentlyDenied = false;

  // Live transform for the floated product image: drag (focal translation) +
  // pinch-zoom (scale) + two-finger rotate (rotation), composed each gesture.
  Matrix4 _matrix = Matrix4.identity();
  Matrix4 _sessionMatrix = Matrix4.identity();
  Offset _sessionFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _setup();
  }

  Future<void> _setup() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _permanentlyDenied = status.isPermanentlyDenied;
            _error = tr('product.ar_fallback_camera_error');
          });
        }
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _error = tr('product.ar_fallback_camera_error'));
        }
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e, st) {
      talker.handle(e, st, '[fallback-2d-camera] setup failed');
      if (mounted) {
        setState(() => _error = tr('product.ar_fallback_camera_error'));
      }
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _sessionMatrix = _matrix;
    _sessionFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    // Scale + rotate about the gesture's focal point, then translate the focal
    // point to where it is now — natural pan/zoom/rotate. Composed onto the
    // matrix captured at gesture start.
    final transform = Matrix4.identity()
      ..translateByDouble(d.localFocalPoint.dx, d.localFocalPoint.dy, 0, 1)
      ..rotateZ(d.rotation)
      ..scaleByDouble(d.scale, d.scale, 1, 1)
      ..translateByDouble(-_sessionFocal.dx, -_sessionFocal.dy, 0, 1);
    setState(() => _matrix = transform.multiplied(_sessionMatrix));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final c = _controller;
      if (c != null && c.value.isInitialized) {
        c.dispose();
        _controller = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null && _error == null && mounted) {
        setState(() => _initFuture = _setup());
      }
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
    final imgW = MediaQuery.of(context).size.width * 0.55;
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (_error != null) {
            return _ErrorView(
              message: _error!,
              showSettings: _permanentlyDenied,
              onClose: () => Navigator.of(context).maybePop(),
            );
          }
          final c = _controller;
          if (c == null || !c.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              _FullBleedCamera(controller: c),

              // The floated, manipulable product image. The opaque gesture
              // layer fills the screen so a drag can start anywhere.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  child: Transform(
                    transform: _matrix,
                    child: Center(
                      child: _ProductOverlay(url: widget.imageUrl, size: imgW),
                    ),
                  ),
                ),
              ),

              _TopBar(onClose: () => Navigator.of(context).maybePop()),
              const _InstructionPill(),
            ],
          );
        },
      ),
    );
  }
}

/// Fills the screen with the live feed (BoxFit.cover semantics) — no letterbox
/// bars on any device ratio. Mirrors the seller scan camera's full-bleed math.
class _FullBleedCamera extends StatelessWidget {
  const _FullBleedCamera({required this.controller});
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

/// The product photo floated over the feed — a soft drop shadow lifts it off
/// the live background so it reads as a placed object. Null/empty url shows a
/// neutral placeholder so the screen is never broken.
class _ProductOverlay extends StatelessWidget {
  const _ProductOverlay({required this.url, required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: hasUrl
          ? Image.network(
              url!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const _PlaceholderCard(),
            )
          : const _PlaceholderCard(),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(Iconsax.gallery, size: 40, color: Colors.black38),
      ),
    );
  }
}

/// Top row: a single circular close button (left). Pinned clear of the notch.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom instruction chip explaining why AR fell back to a manual 2D overlay.
class _InstructionPill extends StatelessWidget {
  const _InstructionPill();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.of(context).padding.bottom + 28,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            tr('product.ar_fallback_hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen camera-error surface (permission denied / no camera). Offers an
/// "open settings" route when the permission was permanently denied.
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.showSettings,
    required this.onClose,
  });

  final String message;
  final bool showSettings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_camera_back,
                  color: Colors.white70,
                  size: 44,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (showSettings) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: openAppSettings,
                    child: Text(tr('product.ar_fallback_open_settings')),
                  ),
                ],
              ],
            ),
          ),
        ),
        _TopBar(onClose: onClose),
      ],
    );
  }
}
