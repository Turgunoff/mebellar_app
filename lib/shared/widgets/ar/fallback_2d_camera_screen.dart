import 'dart:async';
import 'dart:convert' show base64Decode;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show Uint8List, compute;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_fonts.dart';

/// JS→Dart bridges, mirroring the buyer viewer: one streams the captured model
/// canvas back as a data URL, the other reports when the `.glb` has loaded so
/// the save action only fires on a real (non-empty) frame.
const String _shotChannel = 'WoodyArShot';
const String _arChannel = 'WoodyArState';

/// Graceful "manual AR" fallback for the buyer AR viewer on devices that can't
/// run ARCore (Scene Viewer would otherwise bounce the user to the Play Store
/// for a "Google Play Services for AR" build that won't run here).
///
/// Shows a full-screen live camera feed with the product's REAL 3D model
/// floated on top via a transparent `<model-viewer>` — the same `.glb` an AR
/// session would have placed, not a flat gallery photo. The buyer orbits and
/// pinch-zooms the model over their room with model-viewer's own camera
/// controls. No AR, no store redirect, no native ARCore dependency.
class Fallback2DCameraScreen extends StatefulWidget {
  const Fallback2DCameraScreen({
    super.key,
    required this.modelUrl,
    required this.productName,
    this.posterUrl,
  });

  /// The approved `.glb` rendered over the camera feed — the product's real 3D
  /// model (what AR would have placed), not a 2D photo.
  final String modelUrl;
  final String productName;

  /// The product's 2D photo, shown by `<model-viewer>` as a placeholder while
  /// the `.glb` streams in. Null → the model just fades in over the bare feed.
  final String? posterUrl;

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

  /// Guards against a second [_setup] running while one is in flight — e.g. the
  /// `resumed` lifecycle event that fires when the iOS permission alert (itself
  /// an app-inactive transition) is dismissed would otherwise start a duplicate.
  bool _settingUp = false;

  /// The model-viewer WebView controller — needed to run `toDataURL()` for the
  /// save-the-room shot. Set once the WebView exists (not a readiness signal).
  WebViewController? _web;

  /// True only after `<model-viewer>` fires its `load` event; gates the save
  /// action so `toDataURL()` never captures an empty/transparent frame.
  bool _modelReady = false;
  bool _saving = false;

  /// Resolves with the model canvas data URL for the in-flight capture.
  Completer<String>? _shotCompleter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _setup();
  }

  Future<void> _setup() async {
    if (_settingUp) return;
    _settingUp = true;
    try {
      // The native OS popup fires here on the first request. iOS reports a
      // never-asked permission as `denied` until the alert is answered, so we
      // only treat `permanentlyDenied`/`restricted` as the "go to Settings"
      // state — a plain denial just leaves the bare error, re-askable later.
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _permanentlyDenied =
                status.isPermanentlyDenied || status.isRestricted;
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
      appLog.handle(e, st, '[fallback-2d-camera] setup failed');
      if (mounted) {
        setState(() => _error = tr('product.ar_fallback_camera_error'));
      }
    } finally {
      _settingUp = false;
    }
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
      // Re-arm the camera on resume. This covers both a normal app background
      // and — crucially — a return from the OS Settings page after the buyer
      // flipped the camera permission on: we clear any prior permission error
      // first so the screen recovers straight into the live camera instead of
      // stranding the user on the "open Settings" surface.
      if (mounted && _controller == null && !_settingUp) {
        setState(() {
          _error = null;
          _permanentlyDenied = false;
          _initFuture = _setup();
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _onArState(JavaScriptMessage message) {
    if (message.message == 'ready' && mounted && !_modelReady) {
      setState(() => _modelReady = true);
    }
  }

  /// Saves "the piece in your room": flattens the transparent model canvas over
  /// a still grabbed from the live camera, watermarks it, and writes it to the
  /// gallery. Both the camera and the WebView are platform views, so neither a
  /// Flutter `RepaintBoundary` (black) nor `toDataURL()` alone (model only, no
  /// room) can capture the composite — they're captured separately and merged.
  Future<void> _saveToGallery() async {
    if (_saving) return;
    final web = _web;
    final cam = _controller;
    if (web == null || cam == null || !cam.value.isInitialized) return;
    setState(() => _saving = true);
    try {
      // The model, as a transparent PNG sized to the on-screen canvas.
      final modelPng = _bytesFromDataUrl(await _captureCanvas(web));

      // The room behind it, from a single camera still (flash forced off so the
      // capture doesn't blast the scene). A failed grab degrades to a black
      // backdrop in the compositor rather than aborting the save.
      Uint8List? cameraBytes;
      try {
        await cam.setFlashMode(FlashMode.off);
        final shot = await cam.takePicture();
        cameraBytes = await shot.readAsBytes();
      } catch (e, st) {
        appLog.handle(e, st, '[fallback-2d-camera] camera grab failed');
      }

      final framed = await compute(_composeRoomShot, (cameraBytes, modelPng));
      if (!await Gal.requestAccess()) {
        _toast(tr('product.ar_save_denied'));
        return;
      }
      await Gal.putImageBytes(framed, name: 'woody_ar_room_${_product()}');
      _toast(tr('product.ar_saved'));
    } on GalException catch (e) {
      _toast(
        e.type == GalExceptionType.accessDenied
            ? tr('product.ar_save_denied')
            : tr('product.ar_save_failed'),
      );
    } catch (_) {
      _toast(tr('product.ar_save_failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// A stable-ish file suffix from the product name (no DateTime in scope-free
  /// utils); collisions just overwrite, which is fine for a share artefact.
  String _product() =>
      widget.productName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase();

  Future<String> _captureCanvas(WebViewController web) async {
    final completer = Completer<String>();
    _shotCompleter = completer;
    await web.runJavaScript(
      "(function(){try{var mv=document.querySelector('model-viewer');"
      "if(!mv||typeof mv.toDataURL!=='function'){$_shotChannel.postMessage('ERR');return;}"
      "$_shotChannel.postMessage(mv.toDataURL('image/png'));}"
      "catch(e){$_shotChannel.postMessage('ERR');}})();",
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _shotCompleter = null;
        throw TimeoutException('AR canvas capture timed out');
      },
    );
  }

  void _onShot(JavaScriptMessage message) {
    final completer = _shotCompleter;
    if (completer == null || completer.isCompleted) return;
    _shotCompleter = null;
    final data = message.message;
    if (data.startsWith('data:image')) {
      completer.complete(data);
    } else {
      completer.completeError(StateError('AR canvas capture failed'));
    }
  }

  Uint8List _bytesFromDataUrl(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) throw const FormatException('Malformed data URL');
    return base64Decode(dataUrl.substring(comma + 1));
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black.withValues(alpha: 0.85),
          content: Text(
            text,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
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
          final canSave = _web != null && _modelReady;
          return Stack(
            fit: StackFit.expand,
            children: [
              _FullBleedCamera(controller: c),

              // The product's REAL 3D model floated over the live feed via a
              // transparent <model-viewer>. Full-bleed so the buyer can orbit /
              // pinch-zoom the piece anywhere over their room; the transparent
              // canvas + CSS let the camera show through everywhere but the model
              // itself. model-viewer's own camera controls handle the gestures,
              // so no Flutter gesture layer sits above it to steal touches.
              Positioned.fill(
                child: ModelViewer(
                  src: widget.modelUrl,
                  // The 2D photo as a placeholder while the (multi-MB) .glb
                  // streams in; null degrades to a fade-in over the bare feed.
                  poster: widget.posterUrl,
                  alt: widget.productName,
                  // No native AR launcher — THIS screen is the AR fallback for
                  // devices that can't run ARCore, so a Scene-Viewer button would
                  // just dead-end at the Play Store.
                  ar: false,
                  // The buyer drives rotation + pinch-zoom by hand over the feed.
                  cameraControls: true,
                  disableZoom: false,
                  loading: Loading.eager,
                  // Pull the camera back so the model reads at a natural size
                  // over the room instead of filling the frame edge-to-edge.
                  cameraOrbit: '0deg 80deg 130%',
                  // Even, showroom-style lighting + a grounding contact shadow.
                  environmentImage: 'neutral',
                  shadowIntensity: 1,
                  // Transparent so the live camera behind shows through: the
                  // WebView (forced transparent by model_viewer_plus), the
                  // <model-viewer> element, and its default-white poster/page
                  // (killed via --poster-color so it never masks the feed).
                  backgroundColor: Colors.transparent,
                  relatedCss:
                      'html,body{background-color:transparent !important;}'
                      'model-viewer{background-color:transparent !important;'
                      '--poster-color:transparent !important;}',
                  // Signal "loaded" over [_arChannel] so the save action only
                  // arms once the model can actually be captured.
                  relatedJs:
                      '(function(){var mv=document.querySelector("model-viewer");'
                      'if(!mv){return;}'
                      'var fire=function(){try{$_arChannel.postMessage("ready");}'
                      'catch(e){}};'
                      'if(mv.loaded){fire();}'
                      'mv.addEventListener("load",fire);})();',
                  javascriptChannels: {
                    JavascriptChannel(
                      _shotChannel,
                      onMessageReceived: _onShot,
                    ),
                    JavascriptChannel(
                      _arChannel,
                      onMessageReceived: _onArState,
                    ),
                  },
                  onWebViewCreated: (controller) {
                    _web = controller;
                    if (mounted) setState(() {});
                  },
                ),
              ),

              _TopBar(
                onClose: () => Navigator.of(context).maybePop(),
                onSave: _saveToGallery,
                saving: _saving,
                canSave: canSave,
              ),
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

/// Top row: a circular close button (left) and an optional save-to-gallery
/// button (right). Pinned clear of the notch. [onSave] null (e.g. on the error
/// surface) renders close only.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onClose,
    this.onSave,
    this.saving = false,
    this.canSave = false,
  });

  final VoidCallback onClose;
  final Future<void> Function()? onSave;
  final bool saving;
  final bool canSave;

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleButton(icon: Icons.close, onTap: onClose),
              if (onSave != null)
                _CircleButton(
                  icon: Icons.save_alt,
                  busy: saving,
                  onTap: (canSave && !saving) ? onSave : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent dark circular button used in the camera overlay's top bar. A
/// null [onTap] dims the glyph; [busy] swaps in a spinner.
class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap, this.busy = false});

  final IconData icon;
  final FutureOr<void> Function()? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? () => onTap!() : null,
        child: SizedBox(
          width: 42,
          height: 42,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  icon,
                  color: enabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  size: 22,
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

/// Runs in a background isolate (via `compute`): composites the captured
/// transparent model PNG over the camera room still and stamps a "woody.uz"
/// watermark — the shareable "the piece in your room" shot.
///
/// The model PNG is the on-screen canvas size, so the room still is BoxFit.cover
/// fitted to it (matching the live preview's centre-crop) before the model is
/// drawn 1:1 on top. `bakeOrientation` applies the camera's EXIF rotation first,
/// so a sensor-landscape JPEG doesn't land sideways under an upright model. A
/// missing/undecodable still degrades to a black backdrop so a save still works.
Uint8List _composeRoomShot((Uint8List?, Uint8List) data) {
  final (cameraBytes, modelPng) = data;
  final model = img.decodeImage(modelPng);
  if (model == null) return modelPng;
  final w = model.width;
  final h = model.height;

  final canvas = img.Image(width: w, height: h);
  final decoded = cameraBytes == null ? null : img.decodeImage(cameraBytes);
  final room = decoded == null ? null : img.bakeOrientation(decoded);
  if (room != null) {
    final scale = math.max(w / room.width, h / room.height);
    final rw = (room.width * scale).round();
    final rh = (room.height * scale).round();
    final resized = img.copyResize(room, width: rw, height: rh);
    final cropped = img.copyCrop(
      resized,
      x: ((rw - w) / 2).round(),
      y: ((rh - h) / 2).round(),
      width: w,
      height: h,
    );
    img.compositeImage(canvas, cropped);
  } else {
    canvas.clear(img.ColorRgb8(0, 0, 0));
  }

  // The model PNG is transparent everywhere but the piece, so it overlays 1:1.
  img.compositeImage(canvas, model);
  _stampWoodyWatermark(canvas);
  return img.encodePng(canvas);
}

/// Bottom-right translucent "woody.uz" chip — keeps the mark legible on any
/// room/model colour (mirrors the buyer viewer's watermark).
void _stampWoodyWatermark(img.Image canvas) {
  const label = 'woody.uz';
  final font = canvas.width >= 1000 ? img.arial48 : img.arial24;
  final textW = _bitmapTextWidth(font, label);
  final textH = font.lineHeight;
  final margin = (canvas.width * 0.04).round().clamp(16, 56);
  final padX = (textH * 0.55).round();
  final padY = (textH * 0.3).round();
  final tx = canvas.width - margin - textW;
  final ty = canvas.height - margin - textH;

  img.fillRect(
    canvas,
    x1: tx - padX,
    y1: ty - padY,
    x2: tx + textW + padX,
    y2: ty + textH + padY,
    color: img.ColorRgba8(17, 17, 28, 115),
    radius: ((textH + padY * 2) / 2).round(),
  );
  img.drawString(
    canvas,
    label,
    font: font,
    x: tx,
    y: ty,
    color: img.ColorRgba8(255, 255, 255, 240),
  );
}

int _bitmapTextWidth(img.BitmapFont font, String text) {
  var width = 0;
  for (final code in text.codeUnits) {
    final ch = font.characters[code];
    if (ch != null) width += ch.xAdvance;
  }
  return width;
}
