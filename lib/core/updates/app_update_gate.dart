import 'dart:ui';

import 'package:flutter/material.dart';

import '../../config/remote_config.dart';
import '../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../i18n/i18n.dart';
import 'app_update_service.dart';
import 'maintenance_overlay.dart';

/// Mounts inside both MaterialApp builders (customer + seller), above the
/// Navigator, and paints a blocking overlay on top of the whole app at launch:
/// a maintenance freeze (priority) or a mandatory native update.
///
/// The launch check runs once per process (the service is a singleton), so the
/// Phoenix rebirth on a customer↔seller flip doesn't re-evaluate — but each
/// rebirth re-mounts this gate, which keeps rendering whatever the service
/// already holds. Once [AppUpdateService.gateState] is a blocking state, the
/// overlay is strictly non-dismissible (it sits above the Navigator, swallows
/// every gesture, and blocks the Android back button).
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child, this.service});

  final Widget child;

  /// Test seam — widget tests inject a service double; production leaves this
  /// null and uses [AppUpdateService.instance].
  final AppUpdateService? service;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  AppUpdateService get _service => widget.service ?? AppUpdateService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.checkOnLaunch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppGateState>(
      valueListenable: _service.gateState,
      builder: (context, state, child) => Stack(
        fit: StackFit.expand,
        children: [
          child!,
          if (state == AppGateState.maintenance)
            MaintenanceOverlay(
              message: RemoteConfig.instance.maintenanceMessage,
            )
          else if (state == AppGateState.forceUpdate)
            ForceUpdateOverlay(onUpdate: _service.openStore),
        ],
      ),
      child: widget.child,
    );
  }
}

/// Full-screen, non-dismissible glassmorphism surface for a mandatory update.
///
/// The Home screen stays painted underneath and is visibly blurred by a
/// full-bleed [BackdropFilter]; a dark scrim ([ModalBarrier], which also
/// swallows every tap) sits on top of the blur, and the frosted card floats in
/// the centre. [PopScope] blocks the Android back button. Because the gate
/// mounts above the Navigator, no route underneath is ever reachable.
@visibleForTesting
class ForceUpdateOverlay extends StatelessWidget {
  const ForceUpdateOverlay({super.key, required this.onUpdate});

  final Future<void> Function() onUpdate;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // Transparent Material — paints nothing (keeps the glass look) but gives
      // the Text/FilledButton a default text style + ink host. Without it, this
      // overlay sits above the Navigator with no Material ancestor and Flutter
      // paints the debug yellow underline on every Text.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blur the Home screen behind, then lay a dark scrim that also
            // absorbs every tap (dismissible: false → can't be tapped away).
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: const ModalBarrier(
                dismissible: false,
                color: Color(0x4D000000), // black @ 30%
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _GlassCard(onUpdate: onUpdate),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({this.onUpdate});

  final Future<void> Function()? onUpdate;

  @override
  Widget build(BuildContext context) {
    // The card floats over a guaranteed-dark scrim, so its text/foreground are
    // intentionally light constants (like the brand accent) rather than theme
    // tokens — they must read on the frosted glass in both light and dark mode.
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr('update.required_title'),
                textAlign: TextAlign.center,
                style: PremiumTokens.display(size: 22, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                tr('update.required_body'),
                textAlign: TextAlign.center,
                style: PremiumTokens.body(
                  size: 14.5,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onUpdate,
                  style: FilledButton.styleFrom(
                    backgroundColor: PremiumTokens.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    tr('update.update_now'),
                    style: PremiumTokens.body(
                      size: 16,
                      weight: FontWeight.w600,
                      color: Colors.white,
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
