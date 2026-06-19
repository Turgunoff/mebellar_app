import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../r.dart';
import '../theme/app_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/theme_cubit.dart';

/// Premium brand splash, shown on cold start while [_ModeRouter] in main.dart
/// waits for the minimum display duration to elapse before crossfading into
/// the active app shell.
///
/// Design choices:
/// - Background follows the active theme (off-white `#FAFAFA` in light,
///   near-black `#121212` in dark) so the cold-start → first-frame transition
///   stays visually continuous in both modes. The splash sits *above*
///   MaterialApp (no `Theme.of` here), so brightness is read from [ThemeCubit];
///   `ThemeMode.system` falls back to the platform brightness.
/// - The mark is the white cabinet logo (`AssetLogo.woodyLogoMonochrome`) on a
///   terracotta disc, matching the launcher icon. The staggered entrance
///   animation is code-driven, so only the inner asset changes on a rebrand.
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
    _controller = AnimationController(vsync: this, duration: _entranceDuration)
      ..forward();

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
    final mode = context.watch<ThemeCubit>().state.themeMode;
    final isDark = switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    final titleColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final tagColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return ColoredBox(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
                      'Woody',
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 38,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
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
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: tagColor,
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

/// Brand mark: terracotta disc + soft glow behind, the white cabinet logo
/// centered inside (matches the app launcher icon).
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
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Image(
                image: AssetImage(AssetLogo.woodyLogoMonochrome),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
