import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';

/// Full-bleed "connection lost" interrupt — the Flashscore-style blocking gate
/// shown when a critical fetch fails **and there is no cached data to fall back
/// on** (the third tier of the home/catalog network-UX flow).
///
/// Deliberately **theme-independent dark**: a hard connection failure reads as a
/// system-level interrupt, so it pins the dark palette ([AppColors] dark
/// constants) instead of resolving [PremiumTokens] off the active brightness.
/// This is the one sanctioned exception to the "always use a token bag" rule —
/// the surface must look identical in light and dark mode. The brand accent
/// ([AppColors.terracotta]) is a constant either way.
///
/// Presentation only — it knows nothing about any Bloc. The host wires
/// [retrying] (drives the button spinner) and [onRetry] (fires the retry) from
/// its own state, and owns dismissal. Non-dismissible by design:
/// [showNetworkErrorModal] sets `barrierDismissible: false` and the embedded
/// [PopScope] swallows the Android back gesture, so the only way out is the host
/// popping it once the feed recovers.
class FlashscoreNetworkModal extends StatelessWidget {
  const FlashscoreNetworkModal({
    super.key,
    required this.retrying,
    required this.onRetry,
    this.title,
    this.message,
  });

  /// True while a retry is in flight — swaps the button label for a spinner and
  /// disables re-taps.
  final bool retrying;

  /// Fires one retry attempt. Fire-and-forget: the host observes its own state
  /// to flip [retrying] and to dismiss the modal on success.
  final VoidCallback onRetry;

  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    // canPop:false — a blocking gate must survive the system back gesture; it
    // pairs with barrierDismissible:false in [showNetworkErrorModal].
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.darkDivider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 40,
                offset: const Offset(0, 18),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 38,
                  color: AppColors.terracotta,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title ?? tr('network_modal.title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.4,
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message ?? tr('network_modal.message'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: retrying ? null : onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    disabledBackgroundColor: AppColors.terracotta.withValues(
                      alpha: 0.6,
                    ),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: retrying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          tr('common.retry'),
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [FlashscoreNetworkModal] with the blocking configuration baked in:
/// `barrierDismissible: false`, a dimmed scrim, and the **root** navigator so it
/// covers the bottom nav. Pass a [builder] that wires the modal to your state
/// (see `_HomeNetworkGate`) so it can flip the spinner and dismiss itself on
/// recovery. Resolves when the modal is popped.
Future<void> showNetworkErrorModal(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    useRootNavigator: true,
    builder: builder,
  );
}
