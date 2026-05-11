import 'dart:math' as math;

import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/storage/hive_boxes.dart';
import '../../../core/theme/app_colors.dart';

const String _tutorialSeenKey = 'tutorial_seen_v1';

bool isTutorialSeen() {
  final box = sl<Box>(instanceName: HiveBoxes.settings);
  return box.get(_tutorialSeenKey) == true;
}

Future<void> markTutorialSeen() async {
  final box = sl<Box>(instanceName: HiveBoxes.settings);
  await box.put(_tutorialSeenKey, true);
}

/// First-launch onboarding for the customer app — the user's first impression
/// of Woody. Three swipeable slides themed around the furniture journey
/// (discover, order, sell). Once dismissed, [markTutorialSeen] flips a Hive
/// flag so the screen never reappears.
class CustomerTutorialScreen extends StatefulWidget {
  const CustomerTutorialScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<CustomerTutorialScreen> createState() => _CustomerTutorialScreenState();
}

class _CustomerTutorialScreenState extends State<CustomerTutorialScreen> {
  late final PageController _controller = PageController();
  // Continuous page offset (e.g. 1.42 mid-swipe) — drives gradient blend,
  // parallax, and dots so the whole screen tracks the gesture, not just the
  // PageView contents.
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!_controller.hasClients) return;
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markTutorialSeen();
    if (!mounted) return;
    widget.onDone?.call();
  }

  void _next(int slideCount) {
    final current = _page.round();
    if (current >= slideCount - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slides = _slides(isDark);

    final blended = _blendedPalette(slides, _page);
    final activeIndex = _page.round().clamp(0, slides.length - 1);
    final isLast = activeIndex == slides.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [blended.bgTop, blended.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative blurred orbs anchored to the background — give the
              // flat gradient a sense of depth without an asset pipeline.
              Positioned(
                top: -60,
                right: -40,
                child: _Orb(size: 220, color: blended.accent.withValues(alpha: 0.18)),
              ),
              Positioned(
                bottom: -80,
                left: -50,
                child: _Orb(size: 260, color: blended.accent.withValues(alpha: 0.10)),
              ),
              Column(
                children: [
                  _TopBar(
                    onSkip: _finish,
                    foreground: blended.foreground,
                    isLast: isLast,
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: slides.length,
                      itemBuilder: (_, i) => _SlideView(
                        slide: slides[i],
                        page: _page,
                        index: i,
                      ),
                    ),
                  ),
                  _Dots(
                    count: slides.length,
                    page: _page,
                    activeColor: blended.accent,
                    inactiveColor: blended.foreground.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 28),
                  _BottomCta(
                    isLast: isLast,
                    progress: (_page + 1) / slides.length,
                    accent: blended.accent,
                    onTap: () => _next(slides.length),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Slide data ----------------------------------------------------------

  // Woody MVP palette. Each slide picks a wood-tone accent that crossfades
  // with its neighbour as the user swipes — terracotta → warm taupe →
  // espresso slate. Light/dark variants are tuned so the foreground text
  // stays readable on both the gradient and the glassmorphic chips.
  List<_SlideData> _slides(bool isDark) {
    return [
      _SlideData(
        title: tr('tutorial.slide1_title'),
        body: tr('tutorial.slide1_body'),
        bgTop: isDark ? const Color(0xFF231410) : const Color(0xFFFBF1E8),
        bgBottom: isDark ? const Color(0xFF120907) : const Color(0xFFF2DBC4),
        accent: AppColors.terracotta,
        foreground: isDark ? Colors.white : const Color(0xFF2A1A0E),
        scene: _SceneType.welcome,
      ),
      _SlideData(
        title: tr('tutorial.slide2_title'),
        body: tr('tutorial.slide2_body'),
        bgTop: isDark ? const Color(0xFF20180F) : const Color(0xFFFAF3E8),
        bgBottom: isDark ? const Color(0xFF120B06) : const Color(0xFFEAD3B3),
        accent: const Color(0xFFA47148),
        foreground: isDark ? Colors.white : const Color(0xFF2B1E10),
        scene: _SceneType.shop,
      ),
      _SlideData(
        title: tr('tutorial.slide3_title'),
        body: tr('tutorial.slide3_body'),
        bgTop: isDark ? const Color(0xFF181410) : const Color(0xFFEFE6DC),
        bgBottom: isDark ? const Color(0xFF0A0806) : const Color(0xFFCFBFA9),
        accent: isDark
            ? const Color(0xFF7A6754)
            : const Color(0xFF4A3F35),
        foreground: isDark ? Colors.white : const Color(0xFF1E1611),
        scene: _SceneType.deliver,
      ),
    ];
  }

  _Palette _blendedPalette(List<_SlideData> slides, double page) {
    final clamped = page.clamp(0.0, (slides.length - 1).toDouble());
    final lower = clamped.floor();
    final upper = math.min(lower + 1, slides.length - 1);
    final t = clamped - lower;
    final a = slides[lower];
    final b = slides[upper];
    return _Palette(
      bgTop: Color.lerp(a.bgTop, b.bgTop, t)!,
      bgBottom: Color.lerp(a.bgBottom, b.bgBottom, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
    );
  }
}

// --- Top bar ---------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onSkip,
    required this.foreground,
    required this.isLast,
  });

  final VoidCallback onSkip;
  final Color foreground;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          // Wordmark — the brand should be present from the first frame.
          // Playfair Display matches the splash mark and gives the
          // onboarding a premium editorial feel.
          Text(
            'Woody',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: foreground,
              height: 1.0,
            ),
          ),
          const Spacer(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isLast ? 0 : 1,
            child: TextButton(
              onPressed: isLast ? null : onSkip,
              style: TextButton.styleFrom(
                foregroundColor: foreground.withValues(alpha: 0.75),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                tr('common.skip'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Slide layout ----------------------------------------------------------

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.page,
    required this.index,
  });

  final _SlideData slide;
  final double page;
  final int index;

  @override
  Widget build(BuildContext context) {
    // -1..1 distance from this slide; powers a subtle parallax + fade.
    final delta = (index - page).clamp(-1.0, 1.0);
    final parallax = delta * 60;
    final textOpacity = (1 - delta.abs()).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            flex: 6,
            child: Transform.translate(
              offset: Offset(parallax, 0),
              child: _HeroScene(slide: slide, page: page, index: index),
            ),
          ),
          Expanded(
            flex: 3,
            child: Opacity(
              opacity: textOpacity,
              child: Transform.translate(
                offset: Offset(parallax * 0.4, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: slide.foreground,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      slide.body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: slide.foreground.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Hero scene ------------------------------------------------------------

class _HeroScene extends StatelessWidget {
  const _HeroScene({
    required this.slide,
    required this.page,
    required this.index,
  });

  final _SlideData slide;
  final double page;
  final int index;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final scene = SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Concentric soft rings — wood-grain inspired backdrop.
              _Ring(size: size * 0.95, color: slide.accent.withValues(alpha: 0.06)),
              _Ring(size: size * 0.78, color: slide.accent.withValues(alpha: 0.10)),
              _Ring(size: size * 0.58, color: slide.accent.withValues(alpha: 0.16)),
              _hero(slide.scene),
              ..._floaters(slide.scene, size),
            ],
          ),
        );
        return Center(child: scene);
      },
    );
  }

  Widget _hero(_SceneType type) {
    switch (type) {
      case _SceneType.welcome:
        return _HeroCard(
          accent: slide.accent,
          foreground: slide.foreground,
          icon: Icons.weekend_rounded,
          chip: _Chip(
            icon: Icons.auto_awesome_rounded,
            label: 'premium',
            accent: slide.accent,
          ),
        );
      case _SceneType.shop:
        return _HeroCard(
          accent: slide.accent,
          foreground: slide.foreground,
          icon: Icons.shopping_bag_rounded,
          chip: _Chip(
            icon: Icons.bolt_rounded,
            label: '1-tap',
            accent: slide.accent,
          ),
        );
      case _SceneType.deliver:
        return _HeroCard(
          accent: slide.accent,
          foreground: slide.foreground,
          icon: Icons.local_shipping_rounded,
          chip: _Chip(
            icon: Icons.verified_rounded,
            label: 'safe',
            accent: slide.accent,
          ),
        );
    }
  }

  List<Widget> _floaters(_SceneType type, double size) {
    final t = (page - index).clamp(-1.0, 1.0);
    final drift = t * 16;

    Widget place({
      required double left,
      required double top,
      required Widget child,
      double driftFactor = 1,
    }) {
      return Positioned(
        left: left + drift * driftFactor,
        top: top,
        child: child,
      );
    }

    switch (type) {
      case _SceneType.welcome:
        return [
          place(
            left: size * 0.05,
            top: size * 0.12,
            child: _MiniIcon(icon: Icons.king_bed_rounded, accent: slide.accent),
          ),
          place(
            left: size * 0.78,
            top: size * 0.18,
            child: _MiniIcon(icon: Icons.chair_rounded, accent: slide.accent),
            driftFactor: -1,
          ),
          place(
            left: size * 0.72,
            top: size * 0.7,
            child: _MiniIcon(icon: Icons.table_restaurant_rounded, accent: slide.accent),
            driftFactor: 0.6,
          ),
        ];
      case _SceneType.shop:
        return [
          place(
            left: size * 0.08,
            top: size * 0.14,
            child: _MiniIcon(icon: Icons.favorite_rounded, accent: slide.accent),
          ),
          place(
            left: size * 0.74,
            top: size * 0.12,
            child: _MiniIcon(icon: Icons.add_shopping_cart_rounded, accent: slide.accent),
            driftFactor: -1,
          ),
          place(
            left: size * 0.1,
            top: size * 0.7,
            child: _MiniIcon(icon: Icons.payments_rounded, accent: slide.accent),
            driftFactor: 0.6,
          ),
        ];
      case _SceneType.deliver:
        return [
          place(
            left: size * 0.06,
            top: size * 0.16,
            child: _MiniIcon(icon: Icons.inventory_2_rounded, accent: slide.accent),
          ),
          place(
            left: size * 0.78,
            top: size * 0.2,
            child: _MiniIcon(icon: Icons.location_on_rounded, accent: slide.accent),
            driftFactor: -1,
          ),
          place(
            left: size * 0.74,
            top: size * 0.7,
            child: _MiniIcon(icon: Icons.schedule_rounded, accent: slide.accent),
            driftFactor: 0.6,
          ),
        ];
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.accent,
    required this.foreground,
    required this.icon,
    required this.chip,
  });

  final Color accent;
  final Color foreground;
  final IconData icon;
  final Widget chip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.95),
                  Color.lerp(accent, Colors.black, 0.25)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Icon(icon, size: 96, color: Colors.white),
          ),
          Positioned(bottom: -12, child: chip),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.accent});

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: accent, size: 24),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

// --- Dots ------------------------------------------------------------------

class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.page,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int count;
  final double page;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) _dot(i),
      ],
    );
  }

  Widget _dot(int i) {
    // 0..1 weight for this dot — fades color and stretches the active one
    // smoothly during a swipe.
    final weight = (1 - (page - i).abs()).clamp(0.0, 1.0);
    final width = 8 + 24 * weight;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: width,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Color.lerp(inactiveColor, activeColor, weight),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// --- Bottom CTA ------------------------------------------------------------

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.isLast,
    required this.progress,
    required this.accent,
    required this.onTap,
  });

  final bool isLast;
  final double progress;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isLast) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              tr('tutorial.start'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      );
    }

    // Compact circular progress button — visualises how far through the
    // intro the user is and saves horizontal space for the dots above.
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: accent.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
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

// --- Data ------------------------------------------------------------------

enum _SceneType { welcome, shop, deliver }

class _SlideData {
  const _SlideData({
    required this.title,
    required this.body,
    required this.bgTop,
    required this.bgBottom,
    required this.accent,
    required this.foreground,
    required this.scene,
  });

  final String title;
  final String body;
  final Color bgTop;
  final Color bgBottom;
  final Color accent;
  final Color foreground;
  final _SceneType scene;
}

class _Palette {
  const _Palette({
    required this.bgTop,
    required this.bgBottom,
    required this.accent,
    required this.foreground,
  });

  final Color bgTop;
  final Color bgBottom;
  final Color accent;
  final Color foreground;
}
