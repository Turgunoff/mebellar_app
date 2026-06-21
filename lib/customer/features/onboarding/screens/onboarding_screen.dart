import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/storage/app_settings.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../home/widgets/premium/premium_tokens.dart';

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

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const int _pageCount = 3;

  // Guards against a double-tap on Get Started re-firing onDone (and a second
  // DeferredDeepLink.take()) while the markOnboardingSeen() await is in flight.
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
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
    final isLast = _index == _pageCount - 1;

    return Scaffold(
      backgroundColor: pt.background,
      body: SafeArea(
        child: Column(
          children: [
            // Brand wordmark — present from the first frame.
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Woody',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: pt.dark,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _OnboardingPage(
                    title: tr('intro.page1_title'),
                    body: tr('intro.page1_body'),
                    hero: const _ModelHero(),
                  ),
                  _OnboardingPage(
                    title: tr('intro.page2_title'),
                    body: tr('intro.page2_body'),
                    hero: const _ImageHero('assets/images/onboarding_2.png'),
                  ),
                  _OnboardingPage(
                    title: tr('intro.page3_title'),
                    body: tr('intro.page3_body'),
                    hero: const _ImageHero('assets/images/onboarding_3.png'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SmoothPageIndicator(
              controller: _controller,
              count: _pageCount,
              effect: ExpandingDotsEffect(
                activeDotColor: PremiumTokens.accent,
                dotColor: pt.grey.withValues(alpha: 0.28),
                dotHeight: 8,
                dotWidth: 8,
                expansionFactor: 3,
                spacing: 6,
              ),
            ),
            const SizedBox(height: 20),
            _BottomBar(isLast: isLast, onSkip: _finish, onNext: _next),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Shared page scaffold: a flexible hero on top, fixed title + body beneath.
/// The hero takes all remaining space (no fixed height → no overflow on small
/// screens); the text sizes to its content.
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.title,
    required this.body,
    required this.hero,
  });

  final String title;
  final String body;
  final Widget hero;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: Column(
        children: [
          Expanded(child: hero),
          const SizedBox(height: 28),
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
    );
  }
}

/// Page 1 — a live, elegantly spinning 3D chair previewed inside a warm
/// showroom room. `cameraControls`/`disableZoom`/`ar` are all off so it rotates
/// on its own without the user disrupting the framing; the WebView is
/// transparent so the room backdrop behind it shows through (the chair reads as
/// "see it in your space"). The fixed photographic stage isn't a themeable
/// surface, so it doesn't flip with dark mode — same convention as the buyer
/// AR viewer's showroom stage.
class _ModelHero extends StatelessWidget {
  const _ModelHero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/viewer_3d_bg.webp',
            fit: BoxFit.cover,
            // Degrade to a neutral stage if the backdrop can't decode (also
            // keeps widget tests, which have no asset bundle, from throwing).
            errorBuilder: (context, _, _) =>
                ColoredBox(color: PremiumTokens.of(context).imageBg),
          ),
          const ModelViewer(
            src: 'assets/models/onboarding_chair.glb',
            alt: 'Woody 3D furniture',
            ar: false,
            autoRotate: true,
            autoRotateDelay: 0,
            cameraControls: false,
            disableZoom: true,
            disableTap: true,
            disablePan: true,
            // Transparent WebView → the room backdrop shows through.
            backgroundColor: Colors.transparent,
            interactionPrompt: InteractionPrompt.none,
          ),
        ],
      ),
    );
  }
}

/// Pages 2-3 — an aesthetic hero image filling a rounded card.
class _ImageHero extends StatelessWidget {
  const _ImageHero(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, _, _) =>
            ColoredBox(color: PremiumTokens.of(context).imageBg),
      ),
    );
  }
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
