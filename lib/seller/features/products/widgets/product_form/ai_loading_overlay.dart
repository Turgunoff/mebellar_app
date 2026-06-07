import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/theme/app_fonts.dart';
import 'form_kit.dart';

const String _kAiLottieAsset = 'assets/lottie/ai_animation2.json';

/// Decode the (large, ~5MB) Lottie JSON ONCE per app session and reuse the
/// parsed composition. Without this, every overlay show re-parses the whole
/// file on the UI isolate, which is what made the animation appear slowly.
/// Call [AiLoadingOverlay.preload] early (e.g. when the form opens) to warm it.
Future<LottieComposition>? _aiCompositionCache;

Future<LottieComposition> _loadAiComposition() {
  return _aiCompositionCache ??= AssetLottie(_kAiLottieAsset).load();
}

/// Full-screen blocking overlay shown while the AI "fill from photos" request
/// is in flight. A frosted scrim swallows every tap behind it so the form
/// can't be edited mid-fill, with the brand Lottie animation + a caption
/// centred on top.
///
/// Mounted only when [visible] is true (the caller gates on `state.isAiBusy`),
/// so the Lottie controller isn't built/animated when idle.
class AiLoadingOverlay extends StatelessWidget {
  const AiLoadingOverlay({super.key, required this.visible});

  final bool visible;

  /// Warm the composition cache so the first show is instant. Safe to call
  /// repeatedly — the decode runs at most once.
  static void preload() => _loadAiComposition();

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;

    return Positioned.fill(
      // AbsorbPointer + an opaque-ish scrim: nothing behind the overlay can be
      // tapped or focused while the request runs.
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.82),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: FutureBuilder<LottieComposition>(
                    future: _loadAiComposition(),
                    builder: (context, snapshot) {
                      final composition = snapshot.data;
                      if (composition == null) {
                        // Tiny spinner only until the (cached) composition is
                        // ready — instant on every show after the first.
                        return Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(primary),
                            ),
                          ),
                        );
                      }
                      return Lottie(
                        composition: composition,
                        fit: BoxFit.contain,
                        repeat: true,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI rasmlarni o‘qiyapti…',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Mahsulot ma‘lumotlari tayyorlanmoqda',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: kGreyMid,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
