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
                child: Lottie.asset(
                  AssetLottie.searchLottie,
                  fit: BoxFit.contain,
                  // Only animate while it's on screen — no work once faded out.
                  animate: !ready,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
