import 'dart:async';
import 'dart:convert' show base64Decode;

import 'package:flutter/foundation.dart' show Uint8List, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/ar/ar_loading_overlay.dart';
import '../../../../shared/ar/ar_scale.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../../../../shared/models/product_model.dart';
import 'fallback_2d_camera_screen.dart';

/// Clean light "showroom" backdrop behind the model — a flat, premium
/// e-commerce stage (think IKEA/Wayfair) rather than a dark void. Fixed in both
/// light & dark: the AR viewer is its own immersive surface, not a themed page,
/// so the backdrop never flips. The model's own contact shadow + neutral IBL
/// ground it on the light stage.
const Color _kViewerBg = Color(0xFFF4F5F7);
const Color _kInk = Color(0xFF17171C);

/// `_kViewerBg` as 8-bit RGB, so the screenshot compositor can flatten the
/// transparent model-viewer canvas onto the same stage shown on screen.
const int _kViewerBgR = 0xF4;
const int _kViewerBgG = 0xF5;
const int _kViewerBgB = 0xF7;

/// JS→Dart bridges. One streams the captured canvas back as a data URL, the
/// other reports when the device can't launch AR so the CTA never feels dead.
const String _shotChannel = 'WoodyArShot';
const String _arChannel = 'WoodyArState';

/// Immersive, full-screen buyer 3D / AR viewer for an approved `.glb`. Wraps
/// `<model-viewer>` over a clean light stage with idle auto-rotate and full
/// rotate/zoom, a single prominent "place it in your room" AR CTA, and a
/// "save to gallery" action that watermarks the shot for the
/// "place it → screenshot it → share it" viral loop.
///
/// When the product's real dimensions are known the model is rendered
/// true-to-size in AR ([ArScale.fixed] + a per-axis `scale`): Meshy normalises
/// every mesh into a unit cube, so mapping each axis to the measured cm restores
/// the real footprint — a buyer can't pinch a sofa down to the size of a cat.
/// Missing dimensions degrade gracefully to an unscaled model (never a crash).
class BuyerArViewerScreen extends StatefulWidget {
  const BuyerArViewerScreen({super.key, required this.product});

  final ProductModel product;

  @override
  State<BuyerArViewerScreen> createState() => _BuyerArViewerScreenState();
}

class _BuyerArViewerScreenState extends State<BuyerArViewerScreen> {
  /// Set once the WebView controller exists — needed to run JS, but NOT a
  /// readiness signal (model_viewer_plus fires onWebViewCreated *before* it
  /// even loads the page).
  WebViewController? _web;

  /// True only after `<model-viewer>` dispatches its `load` event. The AR + save
  /// actions gate on this: before the model is loaded, `activateAR()` is a
  /// no-op, `canActivateAR` is falsely false, and `toDataURL()` would capture an
  /// empty/transparent frame — so the buttons stay dimmed until it's real.
  bool _modelReady = false;

  /// Resolved by the [_shotChannel] message for the in-flight capture.
  Completer<String>? _shotCompleter;

  bool _saving = false;

  ProductModel get _product => widget.product;

  @override
  Widget build(BuildContext context) {
    final scale = arScaleString(
      _product.widthCm,
      _product.heightCm,
      _product.depthCm,
    );
    final ready = _web != null && _modelReady;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark glyphs read against the light stage.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _kViewerBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      // Transparent Scaffold so the Stack's own background image is the sole
      // backdrop — no solid Scaffold colour can ever paint over the room photo.
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // LAYER 1 — room-context backdrop. A flat _kViewerBg base sits under
            // the photo as a one-frame decode guard / asset-fail fallback (never
            // a black flash); BoxFit.cover keeps the showroom photo edge-to-edge
            // on any ratio so the model reads as placed in a real space.
            Positioned.fill(
              child: ColoredBox(
                color: _kViewerBg,
                child: Image.asset(
                  'assets/images/viewer_3d_bg.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: _kViewerBg),
                ),
              ),
            ),
            Positioned.fill(
              child: ModelViewer(
                src: _product.arModelUrl!,
                // iOS AR Quick Look source (.usdz). Passed straight through —
                // model_viewer_plus writes the `ios-src` attribute only when
                // non-null (see html_builder), so a null usdz simply omits it and
                // iOS falls back to the in-page WebGL view of `src`. No
                // Platform.isIOS branching: the package picks src vs iosSrc by OS.
                iosSrc: _product.usdzUrl,
                // The product's 2D photo as a placeholder while the (multi-MB)
                // .glb streams in — model-viewer shows it + a progress bar over
                // the light stage instead of a blank canvas. Null (no image)
                // degrades to the plain stage, never a crash.
                poster: _product.thumbnail,
                alt: _product.name,
                ar: true,
                // All three launchers offered; model-viewer auto-selects per
                // platform (WebXR / Scene Viewer on Android, Quick Look on iOS
                // when a usdz is present).
                arModes: const ['webxr', 'scene-viewer', 'quick-look'],
                // Lock AR scale to true size so buyers can't pinch-resize the
                // model and misjudge whether it fits their room.
                arScale: scale != null ? ArScale.fixed : null,
                // Furniture is placed on the floor (horizontal surface).
                arPlacement: ArPlacement.floor,
                // `scale` is the native <model-viewer> attribute ('x y z' metre
                // multipliers); the package exposes it as a typed param.
                scale: scale,
                autoRotate: true,
                cameraControls: true,
                // Pull the camera back + tighten the field of view so tall
                // pieces (chairs, wardrobes) get breathing room top & bottom
                // instead of model-viewer's default auto-framing zooming in so
                // tight they read as stretched. The 140% orbit radius zooms out
                // past the ~100% default; a 30° FOV swaps the wide-angle default
                // for a flatter, catalogue-style projection (no fisheye on tall
                // objects). cameraTarget "auto" recentres on the model's
                // bounding box; zoom stays enabled so buyers can still pinch in.
                cameraOrbit: '0deg 75deg 140%',
                fieldOfView: '30deg',
                cameraTarget: 'auto auto auto',
                disableZoom: false,
                // Neutral IBL gives the model even, showroom-style lighting.
                environmentImage: 'neutral',
                // A grounded contact shadow sells the "it's really here" feel.
                shadowIntensity: 1,
                // Transparent canvas (model_viewer_plus also forces the WebView
                // itself transparent) so the room backdrop behind shows through.
                // The saved screenshot still flattens onto _kViewerBg —
                // toDataURL captures only the model canvas, not this
                // Flutter-layer backdrop.
                backgroundColor: Colors.transparent,
                // `backgroundColor` only clears the <model-viewer> element; the
                // host page + the loading "poster" still paint OPAQUE WHITE by
                // default (model-viewer's `--poster-color` is `#fff`), which is
                // the solid white block that covered the room backdrop — most
                // visibly on products with no photo (no poster image to hide it)
                // and during the .glb stream. Force every layer transparent so
                // the Flutter backdrop shows through at all times. Injected at
                // the template's `/* other-css */` slot by model_viewer_plus.
                relatedCss:
                    'html,body{background-color:transparent !important;}'
                    'model-viewer{background-color:transparent !important;'
                    '--poster-color:transparent !important;}',
                loading: Loading.eager,
                // Suppress <model-viewer>'s own bottom-right AR button. It is
                // hidden whenever the device reports no AR support (emulators,
                // ARCore-less phones) — the exact failure this screen works
                // around — so we drive AR from the always-visible Flutter CTA
                // below via activateAR() instead. Replacing the slot's default
                // content with a hidden button removes the native chrome.
                innerModelViewerHtml:
                    '<button slot="ar-button" style="display:none"></button>',
                // Signal real readiness over [_arChannel] when the model's
                // `load` event fires — onWebViewCreated alone is too early
                // (the element isn't upgraded and the .glb hasn't streamed).
                // Runs at parse time, before model-viewer.min.js upgrades the
                // element, so the listener is attached well before `load`.
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
                    onMessageReceived: _onShotMessage,
                  ),
                  JavascriptChannel(
                    _arChannel,
                    onMessageReceived: _onArStateMessage,
                  ),
                },
                onWebViewCreated: (controller) {
                  _web = controller;
                  if (mounted) setState(() {});
                },
              ),
            ),
            // Brand loading animation over the stage until the .glb is loaded;
            // fades out (and stops blocking taps) the moment the model is ready.
            ArModelLoadingOverlay(ready: _modelReady, background: _kViewerBg),
            // Soft top scrim so the dark back/title/save controls keep their
            // contrast over a bright spot in the room backdrop — fades to
            // nothing well above the model. Never intercepts taps.
            const _TopScrim(),
            // LAYER 3 — every control lives inside ONE SafeArea, so nothing can
            // bleed into the notch / status bar. A spaceBetween Column pins the
            // top row (back · title · save) to the top and the AR CTA to the
            // bottom; the empty middle stays transparent and eats no hits, so
            // rotate/zoom gestures fall straight through to the model below.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top controls — back, centered title, save-to-gallery.
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          _CircleIconButton(
                            icon: Iconsax.arrow_left_2_copy,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: AppFonts.body,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: _kInk,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _CircleIconButton(
                            icon: Icons.save_alt,
                            busy: _saving,
                            onTap: (ready && !_saving) ? _saveToGallery : null,
                          ),
                        ],
                      ),
                    ),
                    // Bottom CTA — sits comfortably above the gesture bar with a
                    // generous all-round inset, like a modern full-width action.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                      child: _ArPlaceButton(
                        enabled: ready,
                        onTap: _showArChoiceSheet,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Launches the model-viewer AR session (Scene Viewer / WebXR / Quick Look),
  /// gated on model-viewer's own `canActivateAR` — the exact signal the seller
  /// viewer's (working) native AR button uses.
  ///
  /// We deliberately DON'T pre-check the native `FEATURE_CAMERA_AR` hardware
  /// flag any more: it's declared only by devices that ship ARCore as a system
  /// feature, so it reads `false` on the many phones that get ARCore via the
  /// installable "Google Play Services for AR". That false-negative forced the
  /// 2D fallback on AR-capable buyer devices while the seller viewer (no such
  /// gate) worked on the very same hardware — the bug this fixes. `canActivateAR`
  /// is the accurate runtime gate; when it's genuinely false we still route to
  /// the in-app 2D fallback via the `unsupported` message (never a Play Store
  /// dead-end).
  Future<void> _activateAr() async {
    final web = _web;
    if (web == null) return;
    await web.runJavaScript(
      "(function(){var mv=document.querySelector('model-viewer');"
      'if(!mv){return;}'
      'if(mv.canActivateAR){mv.activateAR();}'
      "else{$_arChannel.postMessage('unsupported');}})();",
    );
  }

  /// Lets the buyer pick how to preview the piece before launching: native
  /// true-to-size 3D AR, or the universal 2D camera overlay. Replaces the old
  /// "tap → straight to AR" so devices that can't run ARCore have an obvious,
  /// first-class path up front, not only the silent `unsupported` fallback.
  Future<void> _showArChoiceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      // The sheet supplies its own rounded white surface; a transparent host
      // lets those corners read over the scrim.
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _ArChoiceSheet(
        onPick3d: () {
          Navigator.of(sheetContext).pop();
          unawaited(_activateAr());
        },
        onPick2d: () {
          Navigator.of(sheetContext).pop();
          _openFallback();
        },
      ),
    );
  }

  /// Opens the 2D camera overlay fallback for the product's main photo.
  void _openFallback() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Fallback2DCameraScreen(
          // The real .glb (non-null here — the viewer only renders with an
          // approved model), so the fallback floats the 3D model, not a photo.
          modelUrl: _product.arModelUrl!,
          posterUrl: _product.thumbnail,
          productName: _product.name,
        ),
      ),
    );
  }

  void _onArStateMessage(JavaScriptMessage message) {
    if (!mounted) return;
    switch (message.message) {
      // The model finished loading — only now are activateAR / canActivateAR /
      // toDataURL meaningful, so reveal the CTA + save action.
      case 'ready':
        if (!_modelReady) setState(() => _modelReady = true);
      // Reached only once the model is loaded (the CTA is gated on readiness),
      // so this is a genuine "no AR on this device" — open the 2D fallback
      // rather than dead-ending on a toast.
      case 'unsupported':
        _openFallback();
    }
  }

  /// Captures the live 3D canvas, watermarks it, and writes it to the camera
  /// roll. PlatformViews (the WebView) return a black frame under Flutter's
  /// `RepaintBoundary`, so we read pixels from the WebGL canvas itself via
  /// `<model-viewer>.toDataURL()` (which forces a render before reading) and
  /// stream the base64 PNG back over [_shotChannel].
  Future<void> _saveToGallery() async {
    if (_saving) return;
    final web = _web;
    if (web == null) return;
    setState(() => _saving = true);
    try {
      final dataUrl = await _captureCanvas(web);
      final raw = _bytesFromDataUrl(dataUrl);
      // Decode + composite + watermark off the UI thread.
      final framed = await compute(_renderWatermarkedPng, raw);

      if (!await Gal.requestAccess()) {
        _toast(tr('product.ar_save_denied'));
        return;
      }
      await Gal.putImageBytes(framed, name: 'woody_ar_${_product.id}');
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

  void _onShotMessage(JavaScriptMessage message) {
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
          backgroundColor: _kInk,
          content: Text(
            text,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }
}

/// Runs in a background isolate (via `compute`): decodes the captured PNG,
/// flattens it onto the showroom backdrop (the model-viewer canvas is
/// transparent, which would otherwise save as black), then stamps a
/// bottom-right "woody.uz" watermark chip. Returns encoded PNG bytes; on a
/// decode failure it falls back to the raw capture so a save still succeeds.
Uint8List _renderWatermarkedPng(Uint8List capturedPng) {
  final shot = img.decodeImage(capturedPng);
  if (shot == null) return capturedPng;

  final canvas = img.Image(width: shot.width, height: shot.height)
    ..clear(img.ColorRgb8(_kViewerBgR, _kViewerBgG, _kViewerBgB));
  img.compositeImage(canvas, shot);

  const label = 'woody.uz';
  final font = canvas.width >= 1000 ? img.arial48 : img.arial24;
  final textW = _bitmapTextWidth(font, label);
  final textH = font.lineHeight;
  final margin = (canvas.width * 0.04).round().clamp(16, 56);
  final padX = (textH * 0.55).round();
  final padY = (textH * 0.3).round();

  final tx = canvas.width - margin - textW;
  final ty = canvas.height - margin - textH;

  // Translucent dark chip behind the text — keeps the mark legible on any
  // model colour (CapCut-style).
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

  return img.encodePng(canvas);
}

int _bitmapTextWidth(img.BitmapFont font, String text) {
  var width = 0;
  for (final code in text.codeUnits) {
    final ch = font.characters[code];
    if (ch != null) width += ch.xAdvance;
  }
  return width;
}

/// A subtle top-down scrim behind the top controls. The room backdrop can be
/// bright where the controls sit, so a soft `_kViewerBg`→transparent fade keeps
/// the dark glyphs/title legible without darkening the model below. Pinned to
/// the top, sized past the controls, and wrapped in [IgnorePointer] so it never
/// eats rotate/zoom gestures.
class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: topInset + 88,
      child: const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xE6F4F5F7), Color(0x00F4F5F7)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Solid white circular icon button with a soft shadow — reads cleanly on the
/// light stage. A null [onTap] dims the glyph; [busy] swaps in a spinner.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final FutureOr<void> Function()? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.white,
      shape: const CircleBorder(
        side: BorderSide(color: Color(0x14000000), width: 1),
      ),
      elevation: 2,
      shadowColor: const Color(0x22000000),
      child: InkWell(
        onTap: enabled ? () => onTap!() : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(_kInk),
                  ),
                )
              : Icon(
                  icon,
                  size: 20,
                  color: enabled ? _kInk : _kInk.withValues(alpha: 0.35),
                ),
        ),
      ),
    );
  }
}

/// Full-width terracotta AR launch CTA pinned to the bottom — the primary,
/// always-visible action that replaces `<model-viewer>`'s unreliable native
/// button. Dims while the viewer is still booting.
class _ArPlaceButton extends StatelessWidget {
  const _ArPlaceButton({required this.enabled, required this.onTap});

  final bool enabled;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? PremiumTokens.accent
          : PremiumTokens.accent.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        onTap: enabled ? () => onTap() : null,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 58,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.d_cube_scan, size: 22, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                tr('product.ar_place_cta'),
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium choice sheet shown before launching: pick native true-to-size 3D AR
/// or the universal 2D camera overlay. Fixed-for-light to match the immersive
/// viewer surface (which never flips with the OS theme).
class _ArChoiceSheet extends StatelessWidget {
  const _ArChoiceSheet({required this.onPick3d, required this.onPick2d});

  final VoidCallback onPick3d;
  final VoidCallback onPick2d;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kInk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                tr('product.ar_choice_title'),
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: _kInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('product.ar_choice_subtitle'),
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: _kInk.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 22),
              _ArChoiceOption(
                icon: Iconsax.d_cube_scan,
                title: tr('product.ar_choice_3d_title'),
                subtitle: tr('product.ar_choice_3d_subtitle'),
                highlighted: true,
                onTap: onPick3d,
              ),
              const SizedBox(height: 12),
              _ArChoiceOption(
                icon: Iconsax.camera,
                title: tr('product.ar_choice_2d_title'),
                subtitle: tr('product.ar_choice_2d_subtitle'),
                highlighted: false,
                onTap: onPick2d,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single tappable choice row: a terracotta-tinted icon tile, a title +
/// subtitle, and a trailing chevron. The recommended ([highlighted]) option
/// gets a filled terracotta tile and a soft accent border to pull the eye.
class _ArChoiceOption extends StatelessWidget {
  const _ArChoiceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlighted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = PremiumTokens.accent;
    return Material(
      color: highlighted
          ? accent.withValues(alpha: 0.07)
          : const Color(0xFFF6F7F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highlighted
              ? accent.withValues(alpha: 0.5)
              : _kInk.withValues(alpha: 0.06),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: highlighted ? accent : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: highlighted ? Colors.white : accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: _kInk.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Iconsax.arrow_right_3_copy,
                size: 18,
                color: _kInk.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
