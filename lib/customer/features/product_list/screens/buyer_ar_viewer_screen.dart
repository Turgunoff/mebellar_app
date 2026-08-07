import 'dart:async';
import 'dart:convert' show base64Decode;

import 'package:flutter/foundation.dart'
    show Uint8List, compute, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/services/facebook_analytics_service.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/ar/ar_activation.dart';
import '../../../../shared/ar/ar_loading_overlay.dart';
import '../../../../shared/ar/ar_set_piece.dart';
import '../../../../shared/ar/glb_cache_manager.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/repositories/product_data_source.dart';
import '../../../../shared/repositories/woody_set_repository.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../cubit/ar_viewer_cubit.dart';
import '../../../../shared/widgets/ar/fallback_2d_camera_screen.dart';
import '../../../../shared/widgets/ar/product_3d_preview_view.dart';
import 'set_ar_viewer_screen.dart';
import 'set_sticker_screen.dart';

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
/// When the product belongs to a furniture set (garnitur) the viewer also
/// surfaces a bottom selector to toggle between every model-bearing piece
/// (e.g. Krovat · Shkaf · Tryumo) without leaving the screen — each `.glb` is
/// pulled from a dedicated on-disk [GlbCacheService] file cache, so a part
/// already seen switches back instantly with no redundant download.
///
/// When the product's real dimensions are known the model is rendered
/// true-to-size in AR ([ArScale.fixed] + a per-axis `scale`): Meshy normalises
/// every mesh into a unit cube, so mapping each axis to the measured cm restores
/// the real footprint — a buyer can't pinch a sofa down to the size of a cat.
/// Missing dimensions degrade gracefully to an unscaled model (never a crash).
class BuyerArViewerScreen extends StatefulWidget {
  const BuyerArViewerScreen({
    super.key,
    required this.product,
    @visibleForTesting this.glbCache,
    @visibleForTesting this.setRepository,
    @visibleForTesting this.productDataSource,
  });

  final ProductModel product;

  /// Test seams: a fake file cache / set repository / data source. In
  /// production all three default to the real [GlbCacheService] and the
  /// DI-registered [WoodySetRepository] / [ProductDataSource].
  final GlbCacheService? glbCache;
  final WoodySetRepository? setRepository;
  final ProductDataSource? productDataSource;

  @override
  State<BuyerArViewerScreen> createState() => _BuyerArViewerScreenState();
}

class _BuyerArViewerScreenState extends State<BuyerArViewerScreen> {
  late final ArViewerCubit _cubit = ArViewerCubit(
    product: widget.product,
    cache: widget.glbCache ?? GlbCacheService(),
    setRepository:
        widget.setRepository ??
        (sl.isRegistered<WoodySetRepository>()
            ? sl<WoodySetRepository>()
            : null),
    productDataSource:
        widget.productDataSource ??
        (sl.isRegistered<ProductDataSource>() ? sl<ProductDataSource>() : null),
  );

  /// Set once the WebView controller exists — needed to run JS, but NOT a
  /// readiness signal (model_viewer_plus fires onWebViewCreated *before* it
  /// even loads the page).
  WebViewController? _web;

  /// Resolved by the [_shotChannel] message for the in-flight capture.
  Completer<String>? _shotCompleter;

  bool _saving = false;

  /// Fires if neither `ready` nor `error` arrives in time — catches the cases
  /// model-viewer can't report (model-viewer.min.js itself blocked, the WebView
  /// silently stalling mid-stream) where no JS event ever comes back. Re-armed
  /// per mounted WebView; the cubit owns the actual ready/failed phase.
  Timer? _watchdog;

  static const Duration _loadTimeout = Duration(seconds: 25);

  ArViewerPart get _part => _cubit.state.selectedPart;

  @override
  void dispose() {
    _watchdog?.cancel();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<ArViewerCubit, ArViewerState>(
        // A fresh render token means a new part is mounting: drop the stale
        // WebView handle and cancel its load watchdog so a late event from the
        // outgoing model can't flip the incoming one's phase. The new
        // ModelViewer re-arms its own watchdog in onWebViewCreated.
        listenWhen: (prev, curr) => prev.renderToken != curr.renderToken,
        listener: (context, state) {
          _watchdog?.cancel();
          _web = null;
        },
        builder: _buildViewer,
      ),
    );
  }

  Widget _buildViewer(BuildContext context, ArViewerState state) {
    final part = state.selectedPart;
    final scale = part.scaleString;
    final modelUrl = state.src;

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
            if (state.showModel && modelUrl != null)
              Positioned.fill(
                // Keyed on the cubit's render token: switching parts / retrying
                // gives a brand-new key, so Flutter tears down the previous
                // WebView (releasing its WebGL context + local proxy) and mounts
                // a fresh ModelViewer for the new `.glb` — a clean hand-off that
                // never leaves the old model leaking behind the new one.
                key: ValueKey(state.renderToken),
                child: ModelViewer(
                  // A `file://` path (cached) loads straight off disk; a remote
                  // URL (cache miss / fallback) streams over the local proxy.
                  src: modelUrl,
                  // iOS AR Quick Look source (.usdz). Passed straight through —
                  // model_viewer_plus writes the `ios-src` attribute only when
                  // non-null (see html_builder), so a null usdz simply omits it and
                  // iOS falls back to the in-page WebGL view of `src`. No
                  // Platform.isIOS branching: the package picks src vs iosSrc by OS.
                  iosSrc: part.usdzUrl,
                  // The product's 2D photo as a placeholder while the (multi-MB)
                  // .glb streams in — model-viewer shows it + a progress bar over
                  // the light stage instead of a blank canvas. Null (no image)
                  // degrades to the plain stage, never a crash.
                  poster: part.posterUrl,
                  alt: part.name,
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
                  // Listen for BOTH `load` (success → "ready") and `error`
                  // (404 / decode / WebGL failure → "error"). Without the error
                  // listener a failed load fires nothing, so "ready" never
                  // arrives and the overlay spins forever — the bug this fixes.
                  // The render token is baked into the payload so a model that
                  // has since been switched away can be identified and ignored:
                  // tearing down the ModelViewer widget closes only its proxy,
                  // not the WebView's JS context, so the outgoing model can
                  // still fire late `load`/`error` (and closing its proxy makes
                  // a stray `error` MORE likely as its in-flight fetches 404).
                  // Without the token a stale event would flip the *incoming*
                  // part's phase (false retry surface, or a premature "ready"
                  // that also cancels the new model's watchdog).
                  relatedJs:
                      '(function(){var mv=document.querySelector("model-viewer");'
                      'if(!mv){return;}'
                      'var fire=function(){try{$_arChannel.postMessage("ready:${state.renderToken}");}'
                      'catch(e){}};'
                      'var fail=function(){try{$_arChannel.postMessage("error:${state.renderToken}");}'
                      'catch(e){}};'
                      'if(mv.loaded){fire();}'
                      'mv.addEventListener("load",fire);'
                      'mv.addEventListener("error",fail);})();',
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
                    _startWatchdog();
                    if (mounted) setState(() {});
                  },
                ),
              ),
            // Brand loading animation over the stage while the .glb downloads /
            // decodes; fades out (and stops blocking taps) the moment the model
            // is ready, or swaps to an actionable retry surface if it fails.
            ArModelLoadingOverlay(
              ready: state.isReady,
              background: _kViewerBg,
              failed: state.isFailed,
              onRetry: _retryLoad,
              errorText: tr('product.ar_load_failed'),
              retryText: tr('product.retry'),
            ),
            // Soft top scrim so the dark back/title/save controls keep their
            // contrast over a bright spot in the room backdrop — fades to
            // nothing well above the model. Never intercepts taps.
            const _TopScrim(),
            // LAYER 3 — every control lives inside ONE SafeArea, so nothing can
            // bleed into the notch / status bar. A spaceBetween Column pins the
            // top row (back · title · save) to the top and the part selector +
            // AR CTA to the bottom; the empty middle stays transparent and eats
            // no hits, so rotate/zoom gestures fall straight through to the
            // model below.
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
                              part.name,
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
                            onTap: (state.isReady && !_saving && _web != null)
                                ? _saveToGallery
                                : null,
                          ),
                        ],
                      ),
                    ),
                    // Bottom — the floating model switcher (set members only)
                    // sits bottom-right, just above the full-width AR CTA. Both
                    // act on the selected part. Same switcher the seller's
                    // Product3DPreviewScreen uses, so both modes are identical.
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.hasMultipleParts)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: 8,
                                bottom: 14,
                              ),
                              child: ArModelSwitcherButton(
                                activeName: part.name,
                                index: state.selectedIndex,
                                total: state.parts.length,
                                onTap: () => showArPartSwitcher(
                                  context,
                                  partNames: [
                                    for (final p in state.parts) p.name,
                                  ],
                                  activeIndex: state.selectedIndex,
                                  onSelect: _cubit.selectPart,
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                          child: _ArPlaceButton(
                            enabled: state.isReady,
                            onTap: _showArChoiceSheet,
                          ),
                        ),
                      ],
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

  /// Launches platform AR for the selected part. iOS opens native Quick Look
  /// when a `.usdz` is available; Android keeps model-viewer's Scene Viewer
  /// path (`canActivateAR` → `activateAR()`).
  Future<void> _activateAr() async {
    final outcome = await ArActivation.activate(
      web: _web,
      arChannel: _arChannel,
      usdzUrl: _part.usdzUrl,
      cache: widget.glbCache ?? GlbCacheService(),
    );
    if (outcome == ArActivationOutcome.unsupported && mounted) {
      _openFallback();
    }
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
          if (sl.isRegistered<FacebookAnalyticsService>()) {
            unawaited(
              sl<FacebookAnalyticsService>().logCustomEvent('ar_model_viewed', {
                'product_id': _part.id,
              }),
            );
          }
          // A garnitur (≥2 model-bearing parts) can't be placed by model-viewer's
          // OS AR — that accepts a single .glb. Hand the whole part list to the
          // native multi-object scene so every piece lands together; a true
          // single product keeps the (correct) single-model activateAR() path.
          if (_cubit.state.hasMultipleParts) {
            unawaited(
              _ensureCameraThen(
                _openMultiObjectAr,
                onBlocked: _openMultiObject2d,
              ),
            );
          } else {
            unawaited(_ensureCameraThen(() => unawaited(_activateAr())));
          }
        },
        onPick2d: () {
          Navigator.of(sheetContext).pop();
          if (_cubit.state.hasMultipleParts) {
            unawaited(
              _ensureCameraThen(
                _openMultiObject2d,
                onBlocked: _openMultiObject2d,
              ),
            );
          } else {
            unawaited(_ensureCameraThen(_openFallback));
          }
        },
      ),
    );
  }

  /// Camera-permission gate for both in-room preview paths. AR launch and the
  /// 2D overlay each put the buyer's live camera on screen, so we request the OS
  /// permission up front — over this viewer, before navigating — instead of
  /// letting the destination ask only after a jarring jump to a black page (the
  /// bug this fixes). The native popup therefore appears on the very first tap.
  ///
  /// - granted → run [onGranted] (launch AR / open the 2D overlay);
  /// - denied (the OS popup was just shown and declined; re-askable on Android)
  ///   → do nothing, so the buyer can simply tap again;
  /// - permanentlyDenied / restricted → run [onBlocked] (defaults to the
  ///   single-model fallback, which surfaces the "Sozlamalarni ochish"
  ///   affordance); the multi-object paths pass their own 2D scene so a garnitur
  ///   never collapses back to a single piece on a denial.
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

  /// Opens the 2D camera overlay fallback for the selected part's model.
  void _openFallback() {
    final part = _part;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/fallback-2d-camera'),
        fullscreenDialog: true,
        builder: (_) => Fallback2DCameraScreen(
          // The real .glb (non-empty here — the viewer only renders with an
          // approved model), so the fallback floats the 3D model, not a photo.
          modelUrl: part.glbUrl,
          posterUrl: part.posterUrl,
          productName: part.name,
        ),
      ),
    );
  }

  /// Every togglable part as a native-placement piece — a garnitur's bed/
  /// wardrobe/dresser, or a set's sibling products. Only model-bearing parts are
  /// on screen, so each carries a real `.glb`.
  List<ArSetPiece> _setPieces() =>
      _cubit.state.parts.map((p) => p.toSetPiece()).toList(growable: false);

  /// Hands the whole part list to the native multi-object AR scene so every
  /// piece lands as a separate, independently movable node — the experience
  /// model-viewer's single-`.glb` OS AR can't deliver.
  void _openMultiObjectAr() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/set-ar-viewer'),
        fullscreenDialog: true,
        builder: (_) => SetArViewerScreen(
          pieces: _setPieces(),
          setName: widget.product.name,
        ),
      ),
    );
  }

  /// The universal 2D dock-based overlay for the whole part list — every device
  /// can run it, and it shares the same piece picker as the AR scene.
  void _openMultiObject2d() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/set-sticker'),
        fullscreenDialog: true,
        builder: (_) => SetStickerScreen(
          pieces: _setPieces(),
          setName: widget.product.name,
        ),
      ),
    );
  }

  void _onArStateMessage(JavaScriptMessage message) {
    if (!mounted) return;
    final raw = message.message;
    final sep = raw.indexOf(':');
    final kind = sep < 0 ? raw : raw.substring(0, sep);
    // `ready`/`error` carry the render token of the WebView that emitted them
    // (see relatedJs). Drop any whose token isn't the current part's, so a
    // model the buyer has switched away from can't flip the live part's phase.
    if (kind == 'ready' || kind == 'error') {
      final token = sep < 0 ? null : int.tryParse(raw.substring(sep + 1));
      if (token != _cubit.state.renderToken) return;
    }
    switch (kind) {
      // The model finished loading — only now are activateAR / canActivateAR /
      // toDataURL meaningful, so reveal the CTA + save action. A late `ready`
      // also recovers from an over-eager watchdog timeout.
      case 'ready':
        _watchdog?.cancel();
        _cubit.onModelRendered();
      // <model-viewer> couldn't load/decode the .glb — surface the retry UI.
      case 'error':
        _failLoad();
      // Reached only once the model is loaded (the CTA is gated on readiness),
      // so this is a genuine "no AR on this device" — open the 2D fallback
      // rather than dead-ending on a toast. Posted by [_activateAr] against the
      // live WebView, so it carries no token.
      case 'unsupported':
        _openFallback();
    }
  }

  /// Arms the load watchdog for a fresh WebView; a prior timer is replaced so a
  /// retry / part-switch never leaves two running.
  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_loadTimeout, () {
      if (mounted && !_cubit.state.isReady) _failLoad();
    });
  }

  void _failLoad() {
    _watchdog?.cancel();
    _cubit.onModelFailed();
  }

  /// Re-attempts the current part's load: drops the stalled WebView handle and
  /// asks the cubit to re-resolve + bump the render token, which gives
  /// [ModelViewer] a new key (fresh WebView, re-armed watchdog).
  void _retryLoad() {
    _watchdog?.cancel();
    _web = null;
    unawaited(_cubit.retry());
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
    // Bind the filename to the part being captured NOW: the selector stays
    // tappable during the async capture/watermark, so reading _part.id later
    // could label this PNG with a sibling the buyer switched to mid-save.
    final partId = _part.id;
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
      await Gal.putImageBytes(framed, name: 'woody_ar_$partId');
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
