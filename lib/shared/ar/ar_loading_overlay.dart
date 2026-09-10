import 'package:flutter/material.dart';
// `AssetLottie` collides with our generated asset constant in r.dart — we want
// ours; the lottie package's same-named provider stays hidden.
import 'package:lottie/lottie.dart' hide AssetLottie;

import '../../r.dart';

/// Full-stage loading overlay shown over the `<model-viewer>` WebView while a
/// (multi-MB) `.glb` streams in. The model-viewer's own poster lives *inside*
/// the WebView; a Flutter Lottie can't render there, so we lay this on top of
/// the viewer instead and fade it out once the model's `load` event fires.
///
/// Driven by [ready]: while false the overlay is opaque (covering the blank
/// canvas with the brand loading animation over the stage [background]); once
/// true it fades out and stops intercepting taps so the model is interactive.
///
/// When [failed] is true the spinner is replaced by an actionable error state
/// (icon + [errorText] + a "[retryText]" button calling [onRetry]). Without
/// this, a `.glb` that 404s, times out, or fails to decode leaves the overlay
/// spinning forever — `<model-viewer>` never fires `load`, so [ready] never
/// flips. The error surface is the recovery path out of that dead end.
class ArModelLoadingOverlay extends StatelessWidget {
  const ArModelLoadingOverlay({
    super.key,
    required this.ready,
    required this.background,
    this.failed = false,
    this.onRetry,
    this.errorText,
    this.retryText,
    this.foreground = const Color(0xFF17171C),
  });

  /// True once `<model-viewer>` has finished loading the model.
  final bool ready;

  /// The viewer stage colour, so the overlay matches the surface behind the
  /// model (light showroom for buyers, themed surface for the seller).
  final Color background;

  /// True when the load gave up (error event or watchdog timeout) — shows the
  /// retry surface instead of an endless spinner.
  final bool failed;

  /// Re-attempts the load. Required (in practice) whenever [failed] can be true.
  final VoidCallback? onRetry;

  /// Localized copy for the error/retry surface; the caller owns i18n vs the
  /// seller's Uzbek-only literals.
  final String? errorText;
  final String? retryText;

  /// Icon/text colour for the error surface, so it reads on [background].
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Positioned.fill(
        child: ColoredBox(
          color: background,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: foreground.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errorText ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: foreground.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (onRetry != null)
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: Text(retryText ?? ''),
                      style: TextButton.styleFrom(
                        foregroundColor: foreground,
                        backgroundColor: foreground.withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Positioned.fill(
      // Stop swallowing gestures the moment the model is ready, even mid-fade.
      child: IgnorePointer(
        ignoring: ready,
        child: AnimatedOpacity(
          opacity: ready ? 0 : 1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          child: ColoredBox(
            color: background,
            child: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                // Only animate while it's on screen — no work once faded out.
                child: _SearchLoopLottie(animate: !ready),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The brand search animation, looped over the part of it that actually moves.
///
/// `search_lottie.json` declares a 150-frame composition, but its last
/// keyframe is at frame 126: the final 24 frames (0.4s at 60fps) are a dead
/// hold that reads as the loader freezing before it snaps back to the start.
/// Frame 126 is identical to frame 0, so looping `0 → 126` is seamless — and
/// [_period] keeps the original playback speed instead of stretching the
/// shortened range over the full duration.
class _SearchLoopLottie extends StatefulWidget {
  const _SearchLoopLottie({required this.animate});

  final bool animate;

  @override
  State<_SearchLoopLottie> createState() => _SearchLoopLottieState();
}

class _SearchLoopLottieState extends State<_SearchLoopLottie>
    with SingleTickerProviderStateMixin {
  static const _contentEnd = 126 / 150;

  late final AnimationController _controller = AnimationController(vsync: this);

  Duration? get _period {
    final total = _controller.duration;
    return total == null ? null : total * _contentEnd;
  }

  void _syncPlayback() {
    final period = _period;
    if (period == null) return;
    if (widget.animate) {
      if (!_controller.isAnimating) {
        _controller.repeat(min: 0, max: _contentEnd, period: period);
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(_SearchLoopLottie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncPlayback();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      AssetLottie.searchLottie,
      controller: _controller,
      fit: BoxFit.contain,
      onLoaded: (composition) {
        _controller.duration = composition.duration;
        _syncPlayback();
      },
    );
  }
}
