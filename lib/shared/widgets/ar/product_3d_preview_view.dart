import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../ar/ar_loading_overlay.dart';
import '../../ar/ar_scale.dart';
import 'fallback_2d_camera_screen.dart';

/// Clean light "showroom" stage behind the model — fixed in both light & dark
/// (the AR preview is its own immersive surface, not a themed page), exactly
/// like the buyer viewer it was lifted from.
const Color _kViewerBg = Color(0xFFF4F5F7);
const Color _kInk = Color(0xFF17171C);

/// JS→Dart bridge: signals when `<model-viewer>` fires `load`/`error`, and when
/// the device can't launch AR (so the CTA routes to the 2D fallback instead of
/// feeling dead).
const String _arChannel = 'WoodyArState';

/// Shared, immersive single-model 3D / AR preview used by BOTH the customer
/// (product detail) and the seller (product management) so they see exactly the
/// same high-quality stage shoppers get: a `<model-viewer>` floating over a
/// blurred interior backdrop, a transparent top bar (back + product name), and
/// one prominent "Xonaga joylashtirish (AR)" CTA that opens a choice sheet —
/// true-to-size native AR (Scene Viewer / Quick Look) or the universal 2D
/// camera overlay.
///
/// Dual-format is preserved: [glbUrl] feeds `<model-viewer src>` (Android /
/// WebGL) and [usdzUrl] feeds `ios-src` (iOS AR Quick Look). model_viewer_plus
/// writes `ios-src` only when non-null, so a null usdz just omits it and iOS
/// falls back to the in-page WebGL view of the `.glb` — no `Platform.isIOS`
/// branching, the package picks the source per OS.
///
/// When the real dimensions are known the model renders true-to-size in AR
/// ([ArScale.fixed] + a per-axis `scale`): Meshy normalises every mesh into a
/// unit cube, so mapping each axis to the measured cm restores the real
/// footprint. Missing dimensions degrade to an unscaled model — never a crash.
class Product3DPreviewScreen extends StatefulWidget {
  const Product3DPreviewScreen({
    super.key,
    required this.glbUrl,
    required this.usdzUrl,
    required this.productName,
    this.posterUrl,
    this.widthCm,
    this.heightCm,
    this.depthCm,
    this.enable2dCamera = true,
  });

  /// The QC-approved `.glb` — `<model-viewer src>` (Android / WebGL / Scene
  /// Viewer).
  final String glbUrl;

  /// iOS-AR (`.usdz`) source for AR Quick Look; null → omitted by
  /// model_viewer_plus and iOS falls back to the in-page WebGL `.glb` view.
  final String? usdzUrl;

  final String productName;

  /// The product's 2D photo, shown as a placeholder (with a progress bar) while
  /// the `.glb` streams in — avoids a blank canvas. Null → plain stage.
  final String? posterUrl;

  final num? widthCm;
  final num? heightCm;
  final num? depthCm;

  /// Whether the choice sheet offers the universal "2D camera" path. Both modes
  /// keep it on by default; pass false to force AR-only.
  final bool enable2dCamera;

  @override
  State<Product3DPreviewScreen> createState() => _Product3DPreviewScreenState();
}

class _Product3DPreviewScreenState extends State<Product3DPreviewScreen> {
  /// Set once the WebView controller exists — needed to run AR JS, but NOT a
  /// readiness signal (model_viewer_plus fires onWebViewCreated before the page
  /// even loads).
  WebViewController? _web;

  /// True only after `<model-viewer>` dispatches its `load` event — the signal
  /// to fade out the loading overlay.
  bool _modelReady = false;

  /// True once the load gave up (error event or watchdog timeout) — shows the
  /// retry surface instead of an endless spinner.
  bool _loadFailed = false;

  /// Catches stalls model-viewer can't report (script blocked, silent mid-
  /// stream stall) where no `load`/`error` event ever arrives.
  Timer? _watchdog;

  /// Bumped on retry to give [ModelViewer] a fresh key (new WebView + reload).
  int _reloadToken = 0;

  static const Duration _loadTimeout = Duration(seconds: 25);

  bool get _ready => _modelReady && !_loadFailed;

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = arScaleString(widget.widthCm, widget.heightCm, widget.depthCm);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark glyphs read against the light stage.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _kViewerBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      // Transparent Scaffold so the Stack's own background image is the sole
      // backdrop — no solid Scaffold colour can paint over the room photo.
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // LAYER 1 — blurred interior backdrop giving the model real-room
            // context. A flat base sits under the photo as a decode guard /
            // asset-fail fallback (never a black flash).
            Positioned.fill(
              child: ColoredBox(
                color: _kViewerBg,
                child: Image.asset(
                  'assets/images/viewer_3d_bg.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(color: _kViewerBg),
                ),
              ),
            ),
            // LAYER 2 — the floating, interactive model.
            Positioned.fill(
              key: ValueKey(_reloadToken),
              child: ModelViewer(
                src: widget.glbUrl,
                iosSrc: widget.usdzUrl,
                poster: widget.posterUrl,
                alt: widget.productName,
                ar: true,
                arModes: const ['webxr', 'scene-viewer', 'quick-look'],
                // Lock AR to true size so the model can't be pinched away from
                // its real footprint; unscaled when dimensions are unknown.
                arScale: scale != null ? ArScale.fixed : null,
                arPlacement: ArPlacement.floor,
                scale: scale,
                autoRotate: true,
                cameraControls: true,
                // Pull the camera back + tighten the FOV so tall pieces get
                // breathing room and don't read as stretched.
                cameraOrbit: '0deg 75deg 140%',
                fieldOfView: '30deg',
                cameraTarget: 'auto auto auto',
                disableZoom: false,
                environmentImage: 'neutral',
                shadowIntensity: 1,
                loading: Loading.eager,
                // Transparent canvas so the room backdrop shows through.
                backgroundColor: Colors.transparent,
                // model-viewer's host page + loading "poster" paint OPAQUE WHITE
                // by default — force every layer transparent so the Flutter
                // backdrop is visible at all times.
                relatedCss:
                    'html,body{background-color:transparent !important;}'
                    'model-viewer{background-color:transparent !important;'
                    '--poster-color:transparent !important;}',
                // Suppress model-viewer's own bottom-right AR button (hidden on
                // AR-less devices — the failure we work around) and drive AR from
                // the always-visible Flutter CTA via activateAR() instead.
                innerModelViewerHtml:
                    '<button slot="ar-button" style="display:none"></button>',
                // Report real readiness over [_arChannel] once `load` fires
                // (onWebViewCreated is too early); listen for `error` too so a
                // failed load surfaces the retry UI instead of spinning forever.
                relatedJs:
                    '(function(){var mv=document.querySelector("model-viewer");'
                    'if(!mv){return;}'
                    'var fire=function(){try{$_arChannel.postMessage("ready");}'
                    'catch(e){}};'
                    'var fail=function(){try{$_arChannel.postMessage("error");}'
                    'catch(e){}};'
                    'if(mv.loaded){fire();}'
                    'mv.addEventListener("load",fire);'
                    'mv.addEventListener("error",fail);})();',
                javascriptChannels: {
                  JavascriptChannel(_arChannel, onMessageReceived: _onArState),
                },
                onWebViewCreated: (controller) {
                  _web = controller;
                  _startWatchdog();
                  if (mounted) setState(() {});
                },
              ),
            ),
            // Brand loading animation over the stage until the .glb is ready, or
            // an actionable retry surface if it fails / stalls.
            ArModelLoadingOverlay(
              ready: _ready,
              background: _kViewerBg,
              failed: _loadFailed,
              onRetry: _retryLoad,
              errorText: tr('product.ar_load_failed'),
              retryText: tr('product.retry'),
            ),
            // Soft top scrim so the back/title controls keep contrast over a
            // bright spot in the backdrop. Never intercepts taps.
            const _TopScrim(),
            // LAYER 3 — controls inside ONE SafeArea. The spaceBetween Column
            // pins the top bar (back · title) and the bottom AR CTA; the empty
            // middle eats no hits, so rotate/zoom gestures fall through to the
            // model.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                              widget.productName,
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
                          // Balances the back button so the title stays centred.
                          const SizedBox(width: 42, height: 42),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                      child: _ArPlaceButton(
                        enabled: _ready,
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

  // ── AR launch ─────────────────────────────────────────────────────────────

  /// Lets the user pick how to preview before launching: native true-to-size
  /// 3D AR, or the universal 2D camera overlay.
  Future<void> _showArChoiceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      // The sheet supplies its own rounded white surface; a transparent host
      // lets those corners read over the scrim.
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _ArChoiceSheet(
        showCamera: widget.enable2dCamera,
        onPick3d: () {
          Navigator.of(sheetContext).pop();
          unawaited(_ensureCameraThen(() => unawaited(_activateAr())));
        },
        onPick2d: () {
          Navigator.of(sheetContext).pop();
          unawaited(_ensureCameraThen(_openFallback));
        },
      ),
    );
  }

  /// Launches the model-viewer AR session (Scene Viewer / WebXR / Quick Look),
  /// gated on model-viewer's own `canActivateAR`. When it's genuinely false we
  /// route to the in-app 2D fallback via the `unsupported` message — never a
  /// Play Store dead-end.
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

  /// Camera-permission gate for both in-room paths. Requested up front (over
  /// this viewer) so the OS popup appears on the first tap, not after a jarring
  /// jump to a black page.
  Future<void> _ensureCameraThen(
    VoidCallback onGranted, {
    VoidCallback? onBlocked,
  }) async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      onGranted();
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      (onBlocked ?? _openFallback)();
    }
  }

  /// Opens the 2D camera overlay floating the real `.glb` over the live feed.
  void _openFallback() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/fallback-2d-camera'),
        fullscreenDialog: true,
        builder: (_) => Fallback2DCameraScreen(
          modelUrl: widget.glbUrl,
          posterUrl: widget.posterUrl,
          productName: widget.productName,
        ),
      ),
    );
  }

  // ── load lifecycle ──────────────────────────────────────────────────────

  void _onArState(JavaScriptMessage message) {
    if (!mounted) return;
    switch (message.message) {
      case 'ready':
        _watchdog?.cancel();
        if (!_modelReady || _loadFailed) {
          setState(() {
            _modelReady = true;
            _loadFailed = false;
          });
        }
      case 'error':
        _failLoad();
      case 'unsupported':
        // canActivateAR was false — fall back to the universal 2D overlay.
        _openFallback();
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_loadTimeout, () {
      if (mounted && !_modelReady) _failLoad();
    });
  }

  void _failLoad() {
    _watchdog?.cancel();
    if (mounted && !_loadFailed) setState(() => _loadFailed = true);
  }

  void _retryLoad() {
    if (!mounted) return;
    setState(() {
      _loadFailed = false;
      _modelReady = false;
      _reloadToken++;
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
// UI primitives — mirror the buyer viewer's premium chrome so customer and
// seller render an identical stage.
// ════════════════════════════════════════════════════════════════════════════

/// Solid white circular icon button with a soft shadow — reads cleanly on the
/// light stage.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

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
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? _kInk : _kInk.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

/// Soft top scrim keeping the back/title controls legible over a bright spot in
/// the backdrop. Fades to nothing well above the model and never eats taps.
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

/// Full-width terracotta AR launch CTA pinned to the bottom — the primary,
/// always-visible action. Dims while the viewer is still booting.
class _ArPlaceButton extends StatelessWidget {
  const _ArPlaceButton({required this.enabled, required this.onTap});

  final bool enabled;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? AppColors.terracotta
          : AppColors.terracotta.withValues(alpha: 0.5),
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
/// viewer surface.
class _ArChoiceSheet extends StatelessWidget {
  const _ArChoiceSheet({
    required this.onPick3d,
    required this.onPick2d,
    required this.showCamera,
  });

  final VoidCallback onPick3d;
  final VoidCallback onPick2d;
  final bool showCamera;

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
              if (showCamera) ...[
                const SizedBox(height: 12),
                _ArChoiceOption(
                  icon: Iconsax.camera,
                  title: tr('product.ar_choice_2d_title'),
                  subtitle: tr('product.ar_choice_2d_subtitle'),
                  highlighted: false,
                  onTap: onPick2d,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A single tappable choice row: a terracotta-tinted icon tile, title +
/// subtitle, trailing chevron. The recommended ([highlighted]) option gets a
/// filled terracotta tile + soft accent border.
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
    const accent = AppColors.terracotta;
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
