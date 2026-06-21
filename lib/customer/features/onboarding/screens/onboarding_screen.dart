import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/storage/app_settings.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../home/widgets/premium/premium_tokens.dart';

/// Fixed dark ink for chrome that floats over page 1's always-light showroom
/// stage (the brand wordmark, the arc track) — it must stay legible there and
/// not flip with the OS theme, the same convention as the buyer AR viewer.
const Color _kStageInk = Color(0xFF17171C);

/// Hive-backed first-launch flag. Mirrors the tutorial's `isTutorialSeen`
/// pattern — the router gates the customer's first navigation on this so the
/// 3D onboarding shows exactly once.
bool isOnboardingSeen() => sl<AppSettings>().onboardingSeen;
Future<void> markOnboardingSeen() => sl<AppSettings>().setOnboardingSeen(true);

/// Customer first-launch onboarding — three swipeable pages that lead with a
/// live, auto-rotating 3D furniture model (page 1) and follow with two
/// aesthetic hero images (pages 2-3). Skip / Get Started both flip the Hive
/// flag via [markOnboardingSeen] and fire [onDone] (the router replays any
/// deferred deep link captured at boot, else lands on home).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onDone});

  /// Called once the user finishes (Skip or Get Started). The flag is already
  /// persisted by the time this fires.
  final VoidCallback? onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();

  // Drives page 2's autonomous cinematic pan-and-zoom. It is NOT tied to the
  // swipe — it plays itself once the swipe fully settles on page 2 (see
  // _handlePageScroll) and rewinds when the user drifts off so it replays on
  // every visit.
  late final AnimationController _panController;
  late final CurvedAnimation _panAnimation;

  int _index = 0;

  static const int _pageCount = 3;

  // Guards against a double-tap on Get Started re-firing onDone (and a second
  // DeferredDeepLink.take()) while the markOnboardingSeen() await is in flight.
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _panController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _panAnimation = CurvedAnimation(
      parent: _panController,
      curve: Curves.easeInOutCubic,
    );
    _controller.addListener(_handlePageScroll);
  }

  /// Plays the page-2 pan-and-zoom the moment the swipe fully settles on page 2
  /// (PageController snaps `page` to an exact integer once idle), and rewinds it
  /// as soon as the user drifts off so it replays on the next visit.
  void _handlePageScroll() {
    if (!_controller.hasClients) return;
    if (_controller.page == 1.0) {
      _panController.forward();
    } else {
      _panController.reset();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePageScroll);
    _controller.dispose();
    _panAnimation.dispose();
    _panController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await markOnboardingSeen();
    if (!mounted) return;
    widget.onDone?.call();
  }

  void _next() {
    if (_index >= _pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLast = _index == _pageCount - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The page-1 showroom runs behind the status bar, so dark glyphs read
      // against its light stage.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: pt.background,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: pt.background,
        // No app bar / bottom nav: the body owns the whole screen, so page 1's
        // backdrop can reach the absolute top and bottom edges.
        extendBody: true,
        extendBodyBehindAppBar: true,
        // The pages own the full screen (no top SafeArea) so the page-1 backdrop
        // bleeds behind the status bar. The footer sits in normal flow below the
        // PageView, so each page stops cleanly above it and the dots/buttons stay
        // stationary across swipes.
        body: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _ModelOnboardingPage(
                    title: tr('intro.page1_title'),
                    body: tr('intro.page1_body'),
                  ),
                  // Page 2 owns the ultra-wide room photo and plays its own
                  // autonomous pan-and-zoom (staircase → sofa) on landing.
                  _PanoramaPage(
                    animation: _panAnimation,
                    title: tr('intro.page2_title'),
                    body: tr('intro.page2_body'),
                  ),
                  // Page 3 is a fully separate layout: an infinite, tilted
                  // marquee of furniture photos behind the final CTA.
                  _MarqueePage(
                    title: tr('intro.page3_title'),
                    body: tr('intro.page3_body'),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _pageCount,
                    effect: ExpandingDotsEffect(
                      activeDotColor: PremiumTokens.accent,
                      // Inactive: small, subtle light-grey dots.
                      dotColor: pt.grey.withValues(alpha: 0.2),
                      dotHeight: 7,
                      dotWidth: 7,
                      // Active swells into a clean terracotta pill.
                      expansionFactor: 3.4,
                      spacing: 7,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _BottomBar(isLast: isLast, onSkip: _finish, onNext: _next),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page 2's autonomous cinematic backdrop: one ultra-wide room photo that pans
/// and zooms by itself once the user lands on the page. The [animation] (a
/// curved 0→1 the parent plays on arrival) drives both a 1.0→1.15 push-in and a
/// `centerLeft`→`centerRight` pan, so the camera glides from the staircase on
/// the left to the pink sofa on the right with a slow zoom. `BoxFit.cover` pins
/// the photo to the screen height; the Stack clips the zoom overflow.
class _PanoramaPage extends StatelessWidget {
  const _PanoramaPage({
    required this.animation,
    required this.title,
    required this.body,
  });

  final Animation<double> animation;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final v = animation.value;
            return Transform.scale(
              // Slow push-in across the pan.
              scale: 1.0 + 0.15 * v,
              child: Image.asset(
                'assets/images/onboarding_panorama.webp',
                fit: BoxFit.cover,
                // Glide the framing left→right: staircase → sofa.
                alignment: Alignment.lerp(
                  Alignment.centerLeft,
                  Alignment.centerRight,
                  v,
                )!,
                // Degrade to a neutral stage if the photo can't decode (also
                // keeps widget tests, which have no asset bundle, from throwing).
                errorBuilder: (context, _, _) => ColoredBox(color: pt.imageBg),
              ),
            );
          },
        ),
        const _MeltGradient(),
        _PageCopy(title: title, body: body),
      ],
    );
  }
}

/// The 12 furniture photos that fill the page-3 marquee, loaded from the
/// `assets/images/onboarding/` folder. Each column wraps over this list with
/// `index % length`, so the streams loop forever.
const List<String> _marqueeImages = [
  'assets/images/onboarding/grid_1.jpeg',
  'assets/images/onboarding/grid_2.jpeg',
  'assets/images/onboarding/grid_3.jpeg',
  'assets/images/onboarding/grid_4.jpeg',
  'assets/images/onboarding/grid_5.jpeg',
  'assets/images/onboarding/grid_6.jpeg',
  'assets/images/onboarding/grid_7.jpeg',
  'assets/images/onboarding/grid_8.jpeg',
  'assets/images/onboarding/grid_9.jpeg',
  'assets/images/onboarding/grid_10.jpeg',
  'assets/images/onboarding/grid_11.jpeg',
  'assets/images/onboarding/grid_12.jpeg',
];

/// Page 3 — a fully separate layout from the page-2 panorama: an infinite,
/// diagonally-tilted marquee of furniture photos behind the final CTA. Three
/// columns auto-scroll on their own (the middle one in the opposite direction,
/// each at its own speed) via a single [Ticker] that nudges each column's
/// [ScrollController] every frame. The lists are unbounded and wrap with
/// `index % images.length`, so they stream forever. A bottom gradient melts the
/// moving grid into the solid app background so the copy stays readable.
class _MarqueePage extends StatefulWidget {
  const _MarqueePage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  State<_MarqueePage> createState() => _MarqueePageState();
}

class _MarqueePageState extends State<_MarqueePage>
    with SingleTickerProviderStateMixin {
  // One scroll controller per column.
  final List<ScrollController> _controllers = List.generate(
    3,
    (_) => ScrollController(),
  );

  // Per-column scroll speed in logical px/ms, deliberately mismatched so the
  // columns never line up.
  static const List<double> _speeds = [0.045, 0.06, 0.035];
  // The middle column runs reversed, so the grid reads as alternating up/down
  // streams. (Reversed lists are driven by the SAME positive offset — `reverse`
  // flips the visual direction, sidestepping negative-offset clamping.)
  static const List<bool> _reversed = [false, true, false];

  // Inferred type avoids importing the scheduler library just to name `Ticker`.
  // `late` lets the initializer reference the instance method `_tick`.
  late final _ticker = createTicker(_tick);

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final ms = elapsed.inMicroseconds / 1000.0;
    for (var i = 0; i < _controllers.length; i++) {
      final c = _controllers[i];
      // hasClients guards the first frames before the ListViews have laid out.
      if (c.hasClients) c.jumpTo(ms * _speeds[i]);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Oversized + tilted so the −0.2 rad rotation still covers the corners;
        // ClipRect trims the overflow back to the page bounds.
        ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gridW = constraints.maxWidth * 1.5;
              final gridH = constraints.maxHeight * 1.7;
              return OverflowBox(
                minWidth: gridW,
                maxWidth: gridW,
                minHeight: gridH,
                maxHeight: gridH,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _controllers.length; i++)
                        Expanded(
                          child: _MarqueeColumn(
                            controller: _controllers[i],
                            reverse: _reversed[i],
                            // Stagger each column's first image so the three
                            // streams don't show the same photos in a row.
                            startOffset: i * 4,
                            imageBg: pt.imageBg,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Melt the moving grid into the solid app background across the bottom
        // ~45% so the CTA copy reads cleanly.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // Fade from the bg colour (alpha 0 → 1) — never
                // Colors.transparent, which would bleed grey mid-fade.
                colors: [
                  pt.background.withValues(alpha: 0),
                  pt.background.withValues(alpha: 0),
                  pt.background,
                ],
                stops: const [0.0, 0.35, 0.58],
              ),
            ),
          ),
        ),
        _PageCopy(title: widget.title, body: widget.body),
      ],
    );
  }
}

/// One auto-scrolling column of the page-3 marquee: an unbounded
/// [ListView.builder] (user scroll disabled — the parent ticker drives it) whose
/// items wrap with `index % images.length` so it never runs out.
class _MarqueeColumn extends StatelessWidget {
  const _MarqueeColumn({
    required this.controller,
    required this.reverse,
    required this.startOffset,
    required this.imageBg,
  });

  final ScrollController controller;
  final bool reverse;
  final int startOffset;
  final Color imageBg;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      reverse: reverse,
      // The ticker owns the scroll; the user can't drag the background.
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final asset =
            _marqueeImages[(index + startOffset) % _marqueeImages.length];
        return Padding(
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => ColoredBox(color: imageBg),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The melt-to-background gradient shared by the image pages: clear through the
/// upper room, fading to the solid app background so the copy reads cleanly and
/// the photo dissolves into the footer beneath. Same treatment as page 1.
class _MeltGradient extends StatelessWidget {
  const _MeltGradient();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Fade from the bg colour (alpha 0 → 1) — never Colors.transparent,
            // which would bleed grey mid-fade.
            colors: [
              pt.background.withValues(alpha: 0),
              pt.background.withValues(alpha: 0),
              pt.background,
            ],
            stops: const [0.0, 0.6, 0.86],
          ),
        ),
      ),
    );
  }
}

/// Title + body copy for the image pages (2-3), anchored just above the footer
/// over the bottom gradient. Mirrors page 1's copy block (minus the arc).
class _PageCopy extends StatelessWidget {
  const _PageCopy({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: pt.dark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: pt.grey,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// JS→Dart bridge: the page-1 `<model-viewer>` posts "ready" over this channel
/// the moment its `load` event fires, so the Lottie loader can fade out exactly
/// when the interactive 3D chair is on screen.
const String _onbReadyChannel = 'WoodyOnbState';

// Arc-slider geometry. The track is a shallow downward "smile" the white thumb
// rides; the thumb sits at the lowest (centre) point on first load.
const double _kArcHeight = 72;
const double _kArcInset = 30; // keeps the thumb + end dots off the edges
const double _kArcSag = 26; // how far the centre dips below the ends
const double _kArcThumbRadius = 11;
const double _kArcEndDotRadius = 3.5;

/// Page 1 — a true full-screen showroom photo (it bleeds behind the status bar)
/// with a static 3D chair the buyer scrubs by hand via a curved arc control.
///
/// The chair never auto-rotates and ignores direct touch
/// (`cameraControls`/`disableZoom`/`disableTap`/`disablePan` all off) so a stray
/// swipe can't tip or zoom it; the pitch is pinned to `90deg` so it stays dead
/// level. Yaw is the only free axis, driven solely by the arc slider. The
/// WebView is transparent so the showroom photo behind it shows through, and the
/// stage is fixed-for-light (doesn't flip with dark mode) — same convention as
/// the buyer AR viewer.
///
/// model_viewer_plus (1.10.0) has no `didUpdateWidget`, so rebuilding with a new
/// `cameraOrbit` never reaches the live `<model-viewer>`. The arc therefore
/// drives the camera straight over JS on the captured [WebViewController] (and
/// crucially does NOT setState the page, so the heavy model never rebuilds and
/// the framing can't jump mid-drag); the `cameraOrbit` param only seeds the
/// initial centred framing.
class _ModelOnboardingPage extends StatefulWidget {
  const _ModelOnboardingPage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  State<_ModelOnboardingPage> createState() => _ModelOnboardingPageState();
}

class _ModelOnboardingPageState extends State<_ModelOnboardingPage>
    with AutomaticKeepAliveClientMixin {
  WebViewController? _web;

  // Keep page 1 alive so the heavy WebGL ModelViewer isn't torn down + re-
  // initialised (re-showing the Lottie loader) when the user swipes to page 3
  // and back. PageView wraps each child in an AutomaticKeepAlive, so this is all
  // it takes to preserve the live 3D scene + its current rotation.
  @override
  bool get wantKeepAlive => true;

  /// True once `<model-viewer>` fires its `load` event — the cue to fade the
  /// Lottie loader out.
  bool _modelReady = false;

  /// Set after the fade-out finishes so the looping Lottie is dropped from the
  /// tree entirely (no idle animation ticking behind the live model).
  bool _loaderGone = false;

  /// "ready" arrives once the model's `load` event fires — reveal the chair by
  /// fading the loader.
  void _onModelState(JavaScriptMessage message) {
    if (!mounted || _modelReady) return;
    if (message.message == 'ready') setState(() => _modelReady = true);
  }

  /// Pushes the live camera yaw to the model. [yaw] is degrees, centre = 0,
  /// −180 (full left) … +180 (full right). Pitch stays pinned at 90deg.
  void _onYawChanged(double yaw) {
    final web = _web;
    if (web == null) return;
    // Set the attribute (not the JS property) so it's honoured even before the
    // element upgrades.
    unawaited(
      web.runJavaScript(
        "var mv=document.querySelector('model-viewer');"
        "if(mv){mv.setAttribute('camera-orbit',"
        "'${yaw.toStringAsFixed(1)}deg 90deg auto');}",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final pt = PremiumTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Lowest layer: the full-bleed showroom backdrop, edge to edge (the
            // page has no top SafeArea, so this reaches the absolute top).
            Image.asset(
              'assets/images/onboarding_viewer_1.webp',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              // Degrade to a neutral stage if the backdrop can't decode (also
              // keeps widget tests, which have no asset bundle, from throwing).
              errorBuilder: (context, _, _) => ColoredBox(color: pt.imageBg),
            ),
            // The chair, pushed down the screen so its legs land on the floor
            // highlight in the backdrop instead of floating mid-air. model-viewer
            // centres the model in its canvas, so the canvas top offset (≈18% of
            // the page) sets where the chair rests; tune it if the .glb's bounds
            // change. cameraTarget lifts the focal point a touch more for the
            // final grounded sit.
            Positioned(
              top: height * 0.18,
              left: 0,
              right: 0,
              height: height * 0.6,
              child: ModelViewer(
                src: 'assets/models/onboarding_chair.glb',
                alt: 'Woody 3D furniture',
                ar: false,
                autoRotate: false,
                cameraControls: false,
                disableZoom: true,
                disableTap: true,
                disablePan: true,
                interactionPrompt: InteractionPrompt.none,
                // Seeds the initial centred framing (yaw 0); live yaw is driven
                // over JS from the arc.
                cameraOrbit: '0deg 90deg auto',
                // Lifts the camera's focal point above the model centre, nudging
                // the chair down in-frame so it settles onto the floor highlight.
                cameraTarget: 'auto 0.35m auto',
                // Transparent WebView → the showroom photo shows through.
                backgroundColor: Colors.transparent,
                // Kill <model-viewer>'s default black progress bar at the source:
                // zero out its shadow-DOM CSS variables (the slot override didn't
                // take). Our Lottie loader owns the loading state instead.
                relatedCss:
                    'model-viewer { --progress-bar-height: 0px !important; '
                    '--progress-bar-color: transparent !important; }',
                // Post "ready" the instant the model's `load` event fires so the
                // Lottie loader can fade out exactly when the chair is on screen.
                // Attached at parse time, before model-viewer upgrades the
                // element, so the listener is in place well before `load`.
                relatedJs:
                    '(function(){var mv=document.querySelector("model-viewer");'
                    'if(!mv){return;}'
                    'var fire=function(){try{$_onbReadyChannel.postMessage("ready");}'
                    'catch(e){}};'
                    'if(mv.loaded){fire();}'
                    'mv.addEventListener("load",fire);})();',
                javascriptChannels: {
                  JavascriptChannel(
                    _onbReadyChannel,
                    onMessageReceived: _onModelState,
                  ),
                },
                onWebViewCreated: (controller) => _web = controller,
              ),
            ),
            // Gradient: completely transparent through the upper half, fading to
            // the solid app background by the lower third so the copy reads
            // cleanly and the photo melts seamlessly into the footer below.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      // Fade from the same bg colour (alpha 0 → 1) — never
                      // Colors.transparent, which would bleed grey mid-fade.
                      colors: [
                        pt.background.withValues(alpha: 0),
                        pt.background.withValues(alpha: 0),
                        pt.background,
                      ],
                      // Stay clear through where the grounded chair sits (~60%)
                      // so its legs read crisply, then fade to solid for the copy.
                      stops: const [0.0, 0.6, 0.86],
                    ),
                  ),
                ),
              ),
            ),
            // Animated loader over the chair canvas: a looping Lottie that gives
            // continuous feedback while the WebGL engine boots, then fades out
            // the instant the model's `load` event lands (`_modelReady`) and is
            // dropped from the tree once faded (`_loaderGone`) so it stops
            // ticking. `<model-viewer>` can't render Lottie itself, so this
            // Flutter overlay stands in for a native poster. IgnorePointer keeps
            // it clear of the arc + swipe gestures.
            if (!_loaderGone)
              Positioned(
                top: height * 0.18,
                left: 0,
                right: 0,
                height: height * 0.6,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _modelReady ? 0 : 1,
                    duration: const Duration(milliseconds: 400),
                    onEnd: () {
                      if (_modelReady && !_loaderGone) {
                        setState(() => _loaderGone = true);
                      }
                    },
                    child: Center(
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: Lottie.asset(
                          'assets/lottie/loading_onboarding.json',
                          fit: BoxFit.contain,
                          // No bundle in widget tests (and a corrupt file in
                          // prod) must never throw — just show nothing.
                          errorBuilder: (context, _, _) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Top layer: the curved arc scrub control + page copy, anchored just
            // above the footer.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ArcRotationControl(
                      key: const Key('onboarding_rotation_arc'),
                      onYawChanged: _onYawChanged,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: pt.dark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: pt.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom curved "arc" scrub control for the page-1 chair. A thin smile-shaped
/// track with limit dots at each end and a pure-white thumb that starts dead
/// centre. Horizontal drags slide the thumb along the curve; the centre maps to
/// 0°, full-left to −180° and full-right to +180° of model yaw.
///
/// It owns its own position state and repaints only the [CustomPaint] on drag,
/// so scrubbing never rebuilds the parent (and the 3D framing can't jump).
class _ArcRotationControl extends StatefulWidget {
  const _ArcRotationControl({super.key, required this.onYawChanged});

  final ValueChanged<double> onYawChanged;

  @override
  State<_ArcRotationControl> createState() => _ArcRotationControlState();
}

class _ArcRotationControlState extends State<_ArcRotationControl> {
  /// Position along the arc, 0..1. Starts dead-centre (yaw 0).
  double _t = 0.5;

  void _onDrag(DragUpdateDetails details, double trackWidth) {
    final next = (_t + details.delta.dx / trackWidth).clamp(0.0, 1.0);
    if (next == _t) return;
    setState(() => _t = next);
    // Centre = 0°, full-left = −180°, full-right = +180°.
    widget.onYawChanged((_t - 0.5) * 360);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final trackWidth = width - _kArcInset * 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => _onDrag(details, trackWidth),
          child: CustomPaint(
            size: Size(width, _kArcHeight),
            painter: _ArcSliderPainter(t: _t),
          ),
        );
      },
    );
  }
}

/// Paints the smile-shaped arc track, its end limit dots, and the white thumb
/// at the bezier point for [t]. The control point's x is the track midpoint, so
/// the bezier's x is linear in `t` — the thumb tracks the finger 1:1 while
/// gliding along the curve's dip.
class _ArcSliderPainter extends CustomPainter {
  const _ArcSliderPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final x0 = _kArcInset;
    final x1 = w - _kArcInset;
    final cx = w / 2;
    final yEnd = size.height / 2 - _kArcSag / 2;
    final cy = yEnd + 2 * _kArcSag; // dips the centre downward (a smile)

    final track = Path()
      ..moveTo(x0, yEnd)
      ..quadraticBezierTo(cx, cy, x1, yEnd);
    canvas.drawPath(
      track,
      Paint()
        ..color = _kStageInk.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    final endDot = Paint()..color = _kStageInk.withValues(alpha: 0.32);
    canvas.drawCircle(Offset(x0, yEnd), _kArcEndDotRadius, endDot);
    canvas.drawCircle(Offset(x1, yEnd), _kArcEndDotRadius, endDot);

    // Thumb position on the quadratic bezier at t.
    final mt = 1 - t;
    final tx = mt * mt * x0 + 2 * mt * t * cx + t * t * x1;
    final ty = mt * mt * yEnd + 2 * mt * t * cy + t * t * yEnd;
    final thumb = Offset(tx, ty);

    // Soft drop shadow so the pure-white thumb reads on the light stage.
    canvas.drawCircle(
      thumb.translate(0, 1.5),
      _kArcThumbRadius,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(thumb, _kArcThumbRadius, Paint()..color = Colors.white);
    canvas.drawCircle(
      thumb,
      _kArcThumbRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _kStageInk.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(covariant _ArcSliderPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// Bottom controls: Skip (left, hidden on the last page), and a trailing action
/// that morphs from a circular Next arrow into a "Get Started" pill.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.isLast,
    required this.onSkip,
    required this.onNext,
  });

  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Fixed slot keeps the layout stable as the trailing action grows.
          SizedBox(
            width: 84,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isLast ? 0 : 1,
              child: IgnorePointer(
                ignoring: isLast,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: pt.grey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      tr('common.skip'),
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: isLast
                ? _GetStartedPill(onTap: onNext)
                : _NextCircle(onTap: onNext),
          ),
        ],
      ),
    );
  }
}

class _NextCircle extends StatelessWidget {
  const _NextCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('next'),
      color: PremiumTokens.accent,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: PremiumTokens.accent.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Iconsax.arrow_right_1, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _GetStartedPill extends StatelessWidget {
  const _GetStartedPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('get_started'),
      color: PremiumTokens.accent,
      borderRadius: BorderRadius.circular(28),
      elevation: 4,
      shadowColor: PremiumTokens.accent.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('intro.get_started'),
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Iconsax.arrow_right_1,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
