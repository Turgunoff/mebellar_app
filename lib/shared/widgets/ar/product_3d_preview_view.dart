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
import '../../ar/glb_cache_manager.dart';
import 'fallback_2d_camera_screen.dart';

/// Clean light "showroom" stage behind the model — fixed in both light & dark
/// (the AR preview is its own immersive surface, not a themed page).
const Color _kViewerBg = Color(0xFFF4F5F7);
const Color _kInk = Color(0xFF17171C);

/// JS→Dart bridge: signals `<model-viewer>` `load`/`error`, and when the device
/// can't launch AR (so the CTA routes to the 2D fallback instead of feeling
/// dead).
const String _arChannel = 'WoodyArState';

/// One placeable 3D model in a (possibly multi-part) product — a bedroom set's
/// Krovat / Shkaf / Tryumo, or a standalone product's single model.
class Product3DPart {
  const Product3DPart({
    required this.id,
    required this.name,
    required this.glbUrl,
    this.usdzUrl,
    this.widthCm,
    this.heightCm,
    this.depthCm,
  });

  final String id;

  /// User-visible piece name shown in the title + switcher (e.g. "Krovat").
  final String name;

  /// QC-approved `.glb` — Android / WebGL / Scene Viewer source.
  final String glbUrl;

  /// iOS-AR (`.usdz`) source for AR Quick Look; null → omitted, iOS falls back
  /// to the in-page WebGL `.glb` view.
  final String? usdzUrl;

  /// Real dimensions for true-to-size AR (per axis cm → metre). Null → unscaled.
  final num? widthCm;
  final num? heightCm;
  final num? depthCm;
}

/// Shared, immersive 3D / AR preview used by BOTH the customer (product detail)
/// and the seller (product management). One screen renders the whole product:
/// a `<model-viewer>` floating over a blurred interior backdrop, a transparent
/// top bar (back + "{product} · {part}"), a bottom-right **model switcher** for
/// multi-part sets, and one prominent "Xonaga joylashtirish (AR)" CTA that opens
/// a choice sheet — true-to-size native AR (Scene Viewer / Quick Look) or the
/// universal 2D camera overlay.
///
/// **Multi-part performance.** Only ONE [ModelViewer] is ever in the tree (never
/// an `IndexedStack` of N WebViews — that exhausts WebGL/GPU memory and crashes).
/// Switching a part swaps the single viewer's model: model_viewer_plus has no
/// `didUpdateWidget`, so a model only (re)loads when the widget remounts — we key
/// the viewer on a render token that bumps per switch, tearing the old WebView
/// (and its WebGL context) down before the new one mounts. A [GlbCacheService]
/// file-cache backs it, so a part seen once renders straight from `file://` with
/// no re-download — switching back is instant.
///
/// Dual-format is preserved per part: [Product3DPart.glbUrl] → `src`,
/// [Product3DPart.usdzUrl] → `ios-src`. model_viewer_plus writes `ios-src` only
/// when non-null, so a null usdz simply omits it (no `Platform.isIOS` branch).
class Product3DPreviewScreen extends StatefulWidget {
  const Product3DPreviewScreen({
    super.key,
    required this.parts,
    required this.productName,
    this.initialIndex = 0,
    this.posterUrl,
    this.enable2dCamera = true,
    @visibleForTesting this.glbCache,
  }) : assert(parts.length > 0, 'at least one part is required');

  /// Every model-bearing piece of the product, in display order.
  final List<Product3DPart> parts;

  /// The product / set name; combined with the active part's name in the title
  /// (e.g. "New York · Shkaf") when there is more than one part.
  final String productName;

  /// Which part to show first (e.g. the specific piece whose "AR" button was
  /// tapped). Clamped into range.
  final int initialIndex;

  /// The product's 2D photo, shown as a placeholder while a `.glb` streams in.
  final String? posterUrl;

  /// Whether the choice sheet offers the universal "2D camera" path.
  final bool enable2dCamera;

  /// Test seam: a fake file cache. Production uses the real [GlbCacheService].
  final GlbCacheService? glbCache;

  @override
  State<Product3DPreviewScreen> createState() => _Product3DPreviewScreenState();
}

class _Product3DPreviewScreenState extends State<Product3DPreviewScreen> {
  late final GlbCacheService _cache = widget.glbCache ?? GlbCacheService();

  late int _activeIndex;

  /// The resolved source handed to [ModelViewer] — a `file://` cache path once
  /// resolved, null while the active part is still being fetched.
  String? _src;

  /// Guards against a stale async resolve flipping the wrong part onto the stage
  /// when the user switches fast.
  int _loadToken = 0;

  /// Set once the WebView controller exists — needed to run AR JS, NOT a
  /// readiness signal.
  WebViewController? _web;

  /// True only after `<model-viewer>` dispatches `load` for the active part.
  bool _modelReady = false;

  /// True once the load gave up (download/parse error or watchdog timeout).
  bool _loadFailed = false;

  Timer? _watchdog;

  /// Bumped per (re)load to give [ModelViewer] a fresh key → clean teardown of
  /// the previous WebView before the new one mounts.
  int _reloadToken = 0;

  static const Duration _loadTimeout = Duration(seconds: 25);

  Product3DPart get _active => widget.parts[_activeIndex];
  bool get _isMultiPart => widget.parts.length > 1;
  bool get _ready => _modelReady && !_loadFailed;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialIndex.clamp(0, widget.parts.length - 1);
    unawaited(_resolve(_activeIndex));
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  /// Resolve the active part's `.glb` to a cached `file://` path (instant on a
  /// cache hit, a one-time download on a miss), then remount the viewer onto it.
  Future<void> _resolve(int index) async {
    final token = ++_loadToken;
    final url = widget.parts[index].glbUrl;
    if (url.isEmpty) {
      if (mounted) setState(() => _loadFailed = true);
      return;
    }
    String? path;
    try {
      path = await _cache.peek(url) ?? await _cache.resolve(url);
    } catch (_) {
      if (token == _loadToken && mounted) setState(() => _loadFailed = true);
      return;
    }
    if (token != _loadToken || !mounted) return;
    setState(() {
      _src = path;
      _modelReady = false;
      _loadFailed = false;
      _reloadToken++;
    });
  }

  void _selectPart(int index) {
    if (index == _activeIndex || index < 0 || index >= widget.parts.length) {
      return;
    }
    setState(() {
      _activeIndex = index;
      _src = null; // cover the stage with the overlay until the new part lands
      _modelReady = false;
      _loadFailed = false;
    });
    unawaited(_resolve(index));
  }

  @override
  Widget build(BuildContext context) {
    final scale = arScaleString(
      _active.widthCm,
      _active.heightCm,
      _active.depthCm,
    );
    final title = _isMultiPart
        ? '${widget.productName} · ${_active.name}'
        : widget.productName;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _kViewerBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // LAYER 1 — blurred interior backdrop for real-room context, with a
            // flat base as a decode guard / asset-fail fallback.
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
            // LAYER 2 — the single floating model. Keyed on _reloadToken so a
            // part switch / retry tears the old WebView down and mounts a fresh
            // one on the new source (model_viewer_plus reloads only on remount).
            if (_src != null)
              Positioned.fill(
                key: ValueKey(_reloadToken),
                child: ModelViewer(
                  src: _src!,
                  iosSrc: _active.usdzUrl,
                  poster: widget.posterUrl,
                  alt: _active.name,
                  ar: true,
                  arModes: const ['webxr', 'scene-viewer', 'quick-look'],
                  arScale: scale != null ? ArScale.fixed : null,
                  arPlacement: ArPlacement.floor,
                  scale: scale,
                  autoRotate: true,
                  cameraControls: true,
                  cameraOrbit: '0deg 75deg 140%',
                  fieldOfView: '30deg',
                  cameraTarget: 'auto auto auto',
                  disableZoom: false,
                  environmentImage: 'neutral',
                  shadowIntensity: 1,
                  loading: Loading.eager,
                  backgroundColor: Colors.transparent,
                  relatedCss:
                      'html,body{background-color:transparent !important;}'
                      'model-viewer{background-color:transparent !important;'
                      '--poster-color:transparent !important;}',
                  innerModelViewerHtml:
                      '<button slot="ar-button" style="display:none"></button>',
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
            // Loading animation until the active model is ready (covers the
            // download too — `_src` is null / `_modelReady` false meanwhile), or
            // an actionable retry surface on failure.
            ArModelLoadingOverlay(
              ready: _ready,
              background: _kViewerBg,
              failed: _loadFailed,
              onRetry: () => _resolve(_activeIndex),
              errorText: tr('product.ar_load_failed'),
              retryText: tr('product.retry'),
            ),
            const _TopScrim(),
            // LAYER 3 — controls inside ONE SafeArea. Top bar pinned up, the
            // switcher + AR CTA pinned down; the empty middle eats no hits so
            // rotate/zoom gestures fall through to the model.
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
                              title,
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
                          const SizedBox(width: 42, height: 42),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Model switcher — floats bottom-right, just above the
                        // AR CTA (set products only). The trailing SizedBox keeps
                        // it clear of the full-width button below.
                        if (_isMultiPart)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8, bottom: 14),
                              child: ArModelSwitcherButton(
                                activeName: _active.name,
                                index: _activeIndex,
                                total: widget.parts.length,
                                onTap: _showSwitcherSheet,
                              ),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── model switcher ────────────────────────────────────────────────────────

  Future<void> _showSwitcherSheet() => showArPartSwitcher(
    context,
    partNames: [for (final p in widget.parts) p.name],
    activeIndex: _activeIndex,
    onSelect: _selectPart,
  );

  // ── AR launch ─────────────────────────────────────────────────────────────

  Future<void> _showArChoiceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
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

  /// Launches the model-viewer AR session for the active part, gated on
  /// model-viewer's own `canActivateAR`; routes to the 2D fallback via the
  /// `unsupported` message when AR genuinely isn't available.
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

  /// Opens the 2D camera overlay floating the active part's model over the live
  /// feed (the cached `file://` when available, else the raw URL).
  void _openFallback() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/fallback-2d-camera'),
        fullscreenDialog: true,
        builder: (_) => Fallback2DCameraScreen(
          modelUrl: _src ?? _active.glbUrl,
          posterUrl: widget.posterUrl,
          productName: _active.name,
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
}

// ════════════════════════════════════════════════════════════════════════════
// UI primitives — premium chrome shared by customer & seller.
// ════════════════════════════════════════════════════════════════════════════

/// Floating model switcher — a white pill (3D-cube glyph + active piece name +
/// `index/total`) that opens the part picker. Lives bottom-right, above the AR
/// CTA, for multi-part sets. Public so both the shared [Product3DPreviewScreen]
/// (seller) and the customer's `BuyerArViewerScreen` render the identical
/// switcher; pair it with [showArPartSwitcher].
class ArModelSwitcherButton extends StatelessWidget {
  const ArModelSwitcherButton({
    super.key,
    required this.activeName,
    required this.index,
    required this.total,
    required this.onTap,
  });

  final String activeName;
  final int index;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: 4,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Iconsax (not Material) glyphs already shipped in the release
                // font — using a brand-new Material glyph here would change the
                // tree-shaken MaterialIcons asset and make the build unpatchable.
                const Icon(
                  Iconsax.d_cube_scan,
                  size: 20,
                  color: AppColors.terracotta,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    activeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      color: _kInk,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${index + 1}/$total',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _kInk.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Iconsax.arrow_up_2,
                  size: 16,
                  color: _kInk.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing every part with a checkmark on the active one.
/// Opens the part picker bottom sheet (drag handle, title, one row per part with
/// a checkmark on the active one) and reports the chosen index. Shared by the
/// seller screen and the customer viewer so both switch parts identically. The
/// sheet pops itself before [onSelect] fires.
Future<void> showArPartSwitcher(
  BuildContext context, {
  required List<String> partNames,
  required int activeIndex,
  required ValueChanged<int> onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _PartSwitcherSheet(
      partNames: partNames,
      activeIndex: activeIndex,
      onSelect: (i) {
        Navigator.of(sheetContext).pop();
        onSelect(i);
      },
    ),
  );
}

class _PartSwitcherSheet extends StatelessWidget {
  const _PartSwitcherSheet({
    required this.partNames,
    required this.activeIndex,
    required this.onSelect,
  });

  final List<String> partNames;
  final int activeIndex;
  final ValueChanged<int> onSelect;

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
              const SizedBox(height: 18),
              Text(
                tr('product.ar_parts_title'),
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: _kInk,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < partNames.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _PartRow(
                  index: i,
                  name: partNames[i],
                  active: i == activeIndex,
                  onTap: () => onSelect(i),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.index,
    required this.name,
    required this.active,
    required this.onTap,
  });

  final int index;
  final String name;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.terracotta;
    return Material(
      color: active ? accent.withValues(alpha: 0.07) : const Color(0xFFF6F7F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: active
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
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? accent : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : accent,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  name,
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
              ),
              if (active)
                const Icon(Icons.check_rounded, size: 22, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

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
/// the backdrop. Never eats taps.
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

/// Full-width terracotta AR launch CTA pinned to the bottom. Dims while the
/// viewer is still booting.
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

/// Premium choice sheet shown before launching: native true-to-size 3D AR or
/// the universal 2D camera overlay.
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
/// subtitle, trailing chevron.
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
