import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import '../features/home/widgets/premium/premium_tokens.dart';

/// Full-screen "we couldn't load this" placeholder — the single Scenario-A
/// surface for the customer flow.
///
/// Shown **inline** (as a screen's body) when a primary fetch fails AND there
/// is no cached data to fall back on — e.g. a cold start with no connection.
/// It is deliberately NOT a modal: there is no barrier, the bottom nav stays
/// reachable, and a reconnect repopulates it silently ([NetworkErrorGate]
/// fires the retry the instant the global `NetworkCubit` flips back online).
/// This replaces the old pinned-dark blocking dialog.
///
/// Themed via [PremiumTokens] so it flips correctly in dark mode. [title] /
/// [message] override the default copy for screen-specific wording (catalog,
/// product list, …); the retry label is shared.
class NetworkErrorView extends StatelessWidget {
  const NetworkErrorView({
    super.key,
    required this.onRetry,
    this.title,
    this.message,
  });

  final VoidCallback onRetry;
  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: PremiumTokens.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: PremiumTokens.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title ?? tr('network_error.title'),
              textAlign: TextAlign.center,
              style: PremiumTokens.display(size: 20, letterSpacing: -0.2),
            ),
            const SizedBox(height: 10),
            Text(
              message ?? tr('network_error.message'),
              textAlign: TextAlign.center,
              style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(tr('network_error.retry')),
              style: FilledButton.styleFrom(
                backgroundColor: PremiumTokens.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                textStyle: PremiumTokens.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
