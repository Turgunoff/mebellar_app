import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Premium brand splash, shown on cold start while [_ModeRouter] in main.dart
/// waits for the minimum display duration to elapse before crossfading into
/// the active app shell.
///
/// Design choices:
/// - Off-white background (`#FAFAFA`) matches the customer premium surface,
///   so the cold-start → first-frame transition is visually continuous.
/// - The mark is rendered in code (Playfair "M" inside a terracotta disc) so
///   we don't ship a PNG asset that would need light/dark variants and HiDPI
///   buckets. If a designer drops a real logo later, swap the inner Container
///   for `Image.asset(...)` — the surrounding animation stays.
/// - Three staggered fade/scale entries give the screen a sense of arrival
///   without feeling slow; total entrance settles by ~750 ms.
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _entranceDuration = Duration(milliseconds: 900);

  late final AnimationController _controller;
  late final Animation<double> _markScale;
  late final Animation<double> _markFade;
  late final Animation<double> _wordmarkFade;
  late final Animation<double> _tagFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _entranceDuration,
    )..forward();

    // Staggered Intervals: mark first, wordmark a beat later, tagline last.
    // Curves.easeOutCubic feels premium — quick start, gentle arrival.
    _markScale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _markFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _wordmarkFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
    );
    _tagFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, child) => Opacity(
                      opacity: _markFade.value,
                      child: Transform.scale(
                        scale: _markScale.value,
                        child: child,
                      ),
                    ),
                    child: const _BrandMark(),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _wordmarkFade,
                    child: Text(
                      'Mebellar',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 38,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextPrimary,
                        letterSpacing: -0.8,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _tagFade,
                    child: Text(
                      'Premium mebel olami',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.lightTextSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: FadeTransition(
                opacity: _tagFade,
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.terracotta,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Code-rendered monogram. Terracotta disc + soft glow behind, white
/// Playfair "M" centered inside. Replace with an asset later by swapping
/// the inner stack for `Image.asset('assets/images/logo.png')`.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft halo — communicates "brand surface" rather than a hard chip.
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.terracotta.withValues(alpha: 0.10),
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.terracotta,
              boxShadow: [
                BoxShadow(
                  color: AppColors.terracotta.withValues(alpha: 0.32),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                  spreadRadius: -6,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'M',
              style: GoogleFonts.playfairDisplay(
                fontSize: 46,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.0,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
