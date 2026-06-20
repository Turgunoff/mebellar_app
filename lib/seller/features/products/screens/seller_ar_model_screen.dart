import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/ar/ar_loading_overlay.dart';
import '../../../../shared/ar/ar_scale.dart';

/// JS→Dart bridge: signals when `<model-viewer>` fires its `load` event, so the
/// loading overlay can fade out only once the model is genuinely ready (mirrors
/// the buyer viewer).
const String _arChannel = 'WoodyArState';

/// Seller-side 3D viewer for their own QC-approved `.glb` — the same
/// `<model-viewer>` the buyer sees, so the seller previews exactly what
/// shoppers will. Idle auto-rotate + rotate/zoom controls, plus AR
/// ("view in your room"). Uzbek-only with seller tokens, matching the rest of
/// the seller product surface.
///
/// When the product's real dimensions are known the model renders true-to-size
/// in AR (Meshy normalises every mesh, so a per-axis cm→metre multiply restores
/// the real footprint); otherwise it renders unscaled — never crashes on a
/// missing dimension.
class SellerArModelScreen extends StatefulWidget {
  const SellerArModelScreen({
    super.key,
    required this.modelUrl,
    this.usdzUrl,
    this.posterUrl,
    required this.productName,
    this.widthCm,
    this.heightCm,
    this.depthCm,
  });

  final String modelUrl;

  /// iOS-AR (.usdz) source for AR Quick Look; null → omitted by
  /// model_viewer_plus and iOS falls back to the in-page WebGL `.glb` view.
  final String? usdzUrl;

  /// The product's 2D photo, shown as a placeholder (with a progress bar) while
  /// the `.glb` streams in — avoids a blank canvas. Null → plain background.
  final String? posterUrl;
  final String productName;
  final num? widthCm;
  final num? heightCm;
  final num? depthCm;

  @override
  State<SellerArModelScreen> createState() => _SellerArModelScreenState();
}

class _SellerArModelScreenState extends State<SellerArModelScreen> {
  /// True only after `<model-viewer>` dispatches its `load` event — the signal
  /// to fade out the loading overlay (onWebViewCreated alone is too early).
  bool _modelReady = false;

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    final scale = arScaleString(
      widget.widthCm,
      widget.heightCm,
      widget.depthCm,
    );
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: c.ink),
        title: Text(
          '3D model',
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ModelViewer(
              src: widget.modelUrl,
              // The product's 2D photo as a placeholder while the .glb
              // downloads — model-viewer shows it + a progress bar over the
              // themed background (no white flash in dark mode). Null → plain
              // background.
              poster: widget.posterUrl,
              // Start streaming the .glb immediately (not lazily) so the poster
              // + loading overlay hand off to the live model fast — mirrors the
              // buyer viewer, avoiding a poster/spinner that lingers.
              loading: Loading.eager,
              // iOS AR Quick Look source (.usdz). Passed through untouched —
              // model_viewer_plus writes `ios-src` only when non-null, so a
              // null usdz simply omits it and iOS falls back to the in-page
              // WebGL `.glb` view. No Platform.isIOS branching: the package
              // picks src vs iosSrc by OS.
              iosSrc: widget.usdzUrl,
              alt: widget.productName,
              ar: true,
              // Mirror the buyer viewer's launchers so the seller previews
              // exactly the same AR behaviour shoppers get (Quick Look on iOS
              // when a usdz exists).
              arModes: const ['webxr', 'scene-viewer', 'quick-look'],
              // Lock AR scale to true size so the seller previews the real
              // footprint and can't pinch-resize away from it.
              arScale: scale != null ? ArScale.fixed : null,
              scale: scale,
              autoRotate: true,
              cameraControls: true,
              backgroundColor: c.background,
              // Fire `ready` over [_arChannel] once the model's `load` event
              // lands. Runs at parse time, before model-viewer.min.js upgrades
              // the element, so the listener is attached well before `load`.
              relatedJs:
                  '(function(){var mv=document.querySelector("model-viewer");'
                  'if(!mv){return;}'
                  'var fire=function(){try{$_arChannel.postMessage("ready");}'
                  'catch(e){}};'
                  'if(mv.loaded){fire();}'
                  'mv.addEventListener("load",fire);})();',
              javascriptChannels: {
                JavascriptChannel(
                  _arChannel,
                  onMessageReceived: (_) {
                    if (mounted && !_modelReady) {
                      setState(() => _modelReady = true);
                    }
                  },
                ),
              },
            ),
          ),
          // Brand loading animation over the stage until the .glb is loaded.
          ArModelLoadingOverlay(ready: _modelReady, background: c.background),
        ],
      ),
    );
  }
}
