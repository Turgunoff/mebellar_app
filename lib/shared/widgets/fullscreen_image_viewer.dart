import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Opens the [FullscreenImageViewer] on the root navigator with a transparent
/// page so the backdrop can fade in *inside* the route instead of fighting
/// the Hero transition (the old version wrapped the page in a
/// `FadeTransition`, which caused the image to "double-fade" — visible as a
/// jump at the start of the animation).
Future<void> openFullscreenImageViewer(
  BuildContext context, {
  required List<String> images,
  required int initialIndex,
  required String heroTagPrefix,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => FullscreenImageViewer(
        images: images,
        initialIndex: initialIndex,
        heroTagPrefix: heroTagPrefix,
      ),
      // No FadeTransition wrapper — Heroes handle the visual; the backdrop
      // fade is driven from inside the page so it cross-fades smoothly with
      // the Hero's flight.
      transitionsBuilder: (_, _, _, child) => child,
    ),
  );
}

/// Telegram-style fullscreen image gallery:
///
///   * horizontal `PageView` to swipe between images;
///   * `InteractiveViewer` per image so the user can pinch-zoom and pan;
///   * vertical drag dismisses the route — the image follows the finger and
///     the backdrop fades as the gesture progresses;
///   * a `flightShuttleBuilder` keeps the BoxFit consistent during the Hero
///     flight so the image doesn't snap between fit modes.
class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.heroTagPrefix,
  });

  final List<String> images;
  final int initialIndex;
  final String heroTagPrefix;

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  double _dragOffset = 0;
  bool _draggingVertically = false;

  /// Dismiss threshold in logical pixels — finger has to travel this far
  /// before lifting up to actually close the gallery. ~120dp matches the
  /// Telegram threshold and feels right on a 6.1" phone.
  static const double _dismissThreshold = 120;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: const [],
    );
  }

  @override
  void dispose() {
    // `edgeToEdge` alone wasn't reliably restoring the status bar on some
    // devices after `immersiveSticky` hid it — leaving the rest of the app
    // running without a visible status bar. `manual` with the full overlay
    // list forces both the status and navigation bars back on.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _pageController.dispose();
    super.dispose();
  }

  void _handleVerticalUpdate(DragUpdateDetails d) {
    setState(() {
      _draggingVertically = true;
      _dragOffset += d.delta.dy;
    });
  }

  void _handleVerticalEnd(DragEndDetails d) {
    final flick = d.primaryVelocity?.abs() ?? 0;
    if (_dragOffset.abs() > _dismissThreshold || flick > 800) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _dragOffset = 0;
      _draggingVertically = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final routeAnim = ModalRoute.of(context)!.animation!;
    final dragProgress = (_dragOffset.abs() / (size.height * 0.6)).clamp(
      0.0,
      1.0,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // Material wrapper gives the Text widgets a DefaultTextStyle ancestor —
      // without it Flutter draws the yellow-underline debug warning over
      // every raw Text (visible as the strikethrough under "1 / 2").
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop. Opacity is the product of (route entry/exit progress)
            // and (1 − drag progress) — both fade out together so dismissing
            // by drag and dismissing by back-gesture look the same.
            AnimatedBuilder(
              animation: routeAnim,
              builder: (_, _) {
                final opacity = (routeAnim.value * (1 - dragProgress * 0.85))
                    .clamp(0.0, 1.0);
                return ColoredBox(
                  color: Colors.black.withValues(alpha: opacity),
                );
              },
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _handleVerticalUpdate,
              onVerticalDragEnd: _handleVerticalEnd,
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  physics: _draggingVertically
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    final url = widget.images[i];
                    return Hero(
                      tag: '${widget.heroTagPrefix}-$i',
                      // Keep the source-style BoxFit.cover during the Hero
                      // flight so the image doesn't snap between fit modes
                      // as the rect grows. Once flight ends, the destination
                      // builder takes over and renders the contain-fit
                      // inside an InteractiveViewer.
                      flightShuttleBuilder: (_, _, _, _, _) {
                        return Material(
                          type: MaterialType.transparency,
                          child: _NetworkImage(url: url, fit: BoxFit.cover),
                        );
                      },
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Center(
                          child: _NetworkImage(url: url, fit: BoxFit.contain),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Top chrome — close button + page indicator. Fades with the route
            // animation so it doesn't blink in/out separately.
            AnimatedBuilder(
              animation: routeAnim,
              builder: (_, child) =>
                  Opacity(opacity: routeAnim.value, child: child),
              child: Stack(
                children: [
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    child: _GlassIconButton(
                      icon: Iconsax.close_square,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  if (widget.images.length > 1)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 14,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          '${_index + 1} / ${widget.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black54,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Network image used both for the destination and the flight shuttle. Kept
/// as a thin wrapper so both ends of the Hero render via the exact same
/// widget tree — any layout work (placeholder, error fallback) is shared.
class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, _) => const ColoredBox(color: Colors.black),
      errorWidget: (_, _, _) => const Center(
        child: Icon(Iconsax.gallery_slash, color: Colors.white54, size: 64),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}
