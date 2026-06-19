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
import '../../../../shared/ar/ar_scale.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../../../../shared/models/product_model.dart';

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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final ready = _web != null && _modelReady;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark glyphs read against the light stage.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _kViewerBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _kViewerBg,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Solid light base — keeps the surface clean (never a black flash)
            // while the model streams in or if the WebView is slow.
            const ColoredBox(color: _kViewerBg, child: SizedBox.expand()),
            Positioned.fill(
              child: ModelViewer(
                src: _product.arModelUrl!,
                // iOS AR Quick Look source (.usdz). Passed straight through —
                // model_viewer_plus writes the `ios-src` attribute only when
                // non-null (see html_builder), so a null usdz simply omits it and
                // iOS falls back to the in-page WebGL view of `src`. No
                // Platform.isIOS branching: the package picks src vs iosSrc by OS.
                iosSrc: _product.usdzUrl,
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
                // Neutral IBL gives the model even, showroom-style lighting.
                environmentImage: 'neutral',
                // A grounded contact shadow sells the "it's really here" feel.
                shadowIntensity: 1,
                backgroundColor: _kViewerBg,
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
            _TopBar(
              productName: _product.name,
              canSave: ready,
              saving: _saving,
              onSave: _saveToGallery,
            ),
            // The single, prominent call to action: a full-width AR launch
            // button pinned above the system nav inset.
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset + 16,
              child: _ArPlaceButton(enabled: ready, onTap: _activateAr),
            ),
          ],
        ),
      ),
    );
  }

  /// Launches the model-viewer AR session (Scene Viewer / WebXR / Quick Look).
  /// When the device can't do AR, model-viewer's `activateAR()` is a silent
  /// no-op, so we probe `canActivateAR` first and surface a soft message
  /// instead of leaving the button feeling broken.
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

  void _onArStateMessage(JavaScriptMessage message) {
    if (!mounted) return;
    switch (message.message) {
      // The model finished loading — only now are activateAR / canActivateAR /
      // toDataURL meaningful, so reveal the CTA + save action.
      case 'ready':
        if (!_modelReady) setState(() => _modelReady = true);
      // Reached only once the model is loaded (the CTA is gated on readiness),
      // so this is a genuine "no AR on this device", not a not-ready-yet race.
      case 'unsupported':
        _toast(tr('product.ar_unsupported'));
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

/// Top overlay: back button, product name, and the save-to-gallery action.
/// Restyled for the light stage — solid surfaces + ink, fixed-for-light (not
/// theme-driven), so it reads against the model on either OS theme.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.productName,
    required this.canSave,
    required this.saving,
    required this.onSave,
  });

  final String productName;
  final bool canSave;
  final bool saving;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _CircleIconButton(
              icon: Iconsax.arrow_left_2,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              busy: saving,
              onTap: (canSave && !saving) ? onSave : null,
            ),
          ],
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
