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
class ArModelLoadingOverlay extends StatelessWidget {
  const ArModelLoadingOverlay({
    super.key,
    required this.ready,
    required this.background,
  });

  /// True once `<model-viewer>` has finished loading the model.
  final bool ready;

  /// The viewer stage colour, so the overlay matches the surface behind the
  /// model (light showroom for buyers, themed surface for the seller).
  final Color background;

  @override
  Widget build(BuildContext context) {
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
