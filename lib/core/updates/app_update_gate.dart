import 'package:flutter/material.dart';

import '../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../i18n/i18n.dart';
import 'app_update_service.dart';

/// Mounts inside both MaterialApp builders (customer + seller) and renders
/// the in-app update surfaces on top of the whole app:
///
///   * [AppUpdateUiState.forceBlocked] — a full-screen blocking overlay when
///     the installed build is below the backend `min_version` and the Play
///     immediate flow was denied or unavailable;
///   * [AppUpdateUiState.flexibleReady] — a bottom "restart to apply" card
///     once a flexible update finished downloading.
///
/// The launch check itself runs once per process (the service is a
/// singleton), so the Phoenix rebirth on a customer↔seller flip doesn't
/// re-prompt — but each rebirth re-mounts this gate, which keeps rendering
/// whatever state the service already holds.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child, this.service});

  final Widget child;

  /// Test seam — widget tests inject a service double; production leaves
  /// this null and uses [AppUpdateService.instance].
  final AppUpdateService? service;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  AppUpdateService get _service => widget.service ?? AppUpdateService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.checkOnLaunch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _service.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUpdateUiState>(
      valueListenable: _service.uiState,
      builder: (context, state, child) => Stack(
        fit: StackFit.expand,
        children: [
          child!,
          if (state == AppUpdateUiState.forceBlocked)
            _ForceUpdateOverlay(onUpdate: _service.retryForcedUpdate),
          if (state == AppUpdateUiState.flexibleReady)
            _RestartBanner(
              onRestart: _service.completeFlexibleUpdate,
              onDismiss: _service.dismissFlexibleBanner,
            ),
        ],
      ),
      child: widget.child,
    );
  }
}

/// Full-screen blocking surface for a mandatory update. Sits above the
/// Navigator, so no route underneath is reachable; system back can only
/// leave the app, and a relaunch lands right back here.
class _ForceUpdateOverlay extends StatelessWidget {
  const _ForceUpdateOverlay({required this.onUpdate});

  final Future<void> Function() onUpdate;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Material(
      color: pt.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  size: 44,
                  color: PremiumTokens.accent,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                tr('update.required_title'),
                textAlign: TextAlign.center,
                style: PremiumTokens.display(size: 24, color: pt.dark),
              ),
              const SizedBox(height: 12),
              Text(
                tr('update.required_body'),
                textAlign: TextAlign.center,
                style: PremiumTokens.body(size: 15, color: pt.grey),
              ),
              const SizedBox(height: 36),
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

/// Bottom floating card shown when a flexible update has downloaded —
/// restarting applies it; dismissing defers (Play installs it on a later
/// background opportunity anyway).
class _RestartBanner extends StatelessWidget {
  const _RestartBanner({required this.onRestart, required this.onDismiss});

  final Future<void> Function() onRestart;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: pt.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: PremiumTokens.cardShadow,
            border: Border.all(color: pt.divider),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.download_done_rounded,
                color: PremiumTokens.accent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('update.ready_title'),
                      style: PremiumTokens.body(
                        size: 14,
                        weight: FontWeight.w600,
                        color: pt.dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('update.ready_body'),
                      style: PremiumTokens.body(size: 12.5, color: pt.grey),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onRestart,
                child: Text(
                  tr('update.restart_now'),
                  style: PremiumTokens.body(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: PremiumTokens.accent,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close_rounded, size: 20, color: pt.grey),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
