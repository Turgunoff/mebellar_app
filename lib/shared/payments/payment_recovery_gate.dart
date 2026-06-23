import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/i18n/i18n.dart';
import '../../core/logging/talker.dart';
import 'pending_payment.dart';
import 'pending_payment_service.dart';

/// Reconciles an in-flight external (Payme/Click) payment when the customer
/// returns to the app, so success is shown only after the server confirms the
/// payment settled — never prematurely on the order-placed event.
///
/// Wraps the app body inside `MaterialApp.builder` (one per mode) and handles
/// two return paths:
///   * **Resume** (the app merely backgrounded while the user paid): a
///     non-dismissible "checking" overlay + bounded polling (default 5 × 3s ≈
///     15s), then a result card. — Task 2.
///   * **Cold start** (the OS killed the app mid-payment): a single status
///     probe on first mount, then a result card. — Task 3.
///
/// The marker is always cleared after one reconciliation pass, so the overlay
/// shows at most once per checkout and can't loop.
class PaymentRecoveryGate extends StatefulWidget {
  const PaymentRecoveryGate({
    super.key,
    required this.child,
    this.onViewDetails,
  });

  final Widget child;

  /// Invoked when the user taps the result card's primary action (orders →
  /// jump to the orders list). Null for surfaces with nowhere to navigate
  /// (seller AR-token / subscription), where the card just dismisses.
  final void Function(PendingPayment payment)? onViewDetails;

  @override
  State<PaymentRecoveryGate> createState() => _PaymentRecoveryGateState();
}

class _PaymentRecoveryGateState extends State<PaymentRecoveryGate>
    with WidgetsBindingObserver {
  /// Gates resume handling until the cold-start probe has run, so a `resumed`
  /// event fired during launch can't race the cold-start pass.
  bool _coldStartDone = false;

  /// A reconciliation pass (cold start or resume) is running — also drives the
  /// non-dismissible "checking" overlay during the resume poll.
  bool _busy = false;

  /// The settled-outcome card to paint over the app, or null when idle.
  _ResultCard? _result;

  PendingPaymentService? get _service =>
      sl.isRegistered<PendingPaymentService>()
      ? sl<PendingPaymentService>()
      : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer to the first frame so the overlay can paint over a mounted tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runColdStart());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Ignore resumes until cold start finished, and never overlap passes.
    if (!_coldStartDone || _busy) return;
    unawaited(_runResume());
  }

  /// Cold-start recovery (Task 3): one probe, then clear — celebratory on PAID,
  /// silent-but-informative otherwise.
  Future<void> _runColdStart() async {
    final service = _service;
    if (service == null) {
      _coldStartDone = true;
      return;
    }
    try {
      final pending = await service.peek();
      if (pending != null) {
        PaymentOutcome outcome;
        try {
          outcome = await service.checkOnce(pending);
        } catch (e, st) {
          talker.handle(e, st, 'PaymentRecoveryGate cold-start probe failed');
          outcome = PaymentOutcome.unknown;
        }
        // Always clear after the cold-start check to prevent an infinite loop.
        await service.clear();
        if (mounted) _present(pending, outcome, coldStart: true);
      }
    } finally {
      _coldStartDone = true;
    }
  }

  /// Resume recovery (Task 2): blocking overlay + bounded poll, then clear.
  Future<void> _runResume() async {
    final service = _service;
    if (service == null) return;
    final pending = await service.peek();
    if (pending == null || !mounted) return;

    setState(() => _busy = true);
    PaymentOutcome outcome;
    try {
      outcome = await service.pollUntilSettled(pending);
    } catch (e, st) {
      talker.handle(e, st, 'PaymentRecoveryGate resume poll failed');
      outcome = PaymentOutcome.unknown;
    }
    // Clear regardless of outcome — one poll cycle per checkout (Task 2).
    await service.clear();
    if (!mounted) return;
    setState(() => _busy = false);
    _present(pending, outcome, coldStart: false);
  }

  void _present(
    PendingPayment pending,
    PaymentOutcome outcome, {
    required bool coldStart,
  }) {
    final paid = outcome == PaymentOutcome.paid;
    final isOrder = pending.kind == PendingPaymentKind.order;
    setState(() {
      _result = _ResultCard(
        success: paid,
        title: _title(paid: paid, coldStart: coldStart),
        body: _body(paid: paid, coldStart: coldStart, isOrder: isOrder),
        // Orders can deep-link to the list; account top-ups just dismiss.
        actionLabel: isOrder && widget.onViewDetails != null
            ? tr('payment.recovery.view_orders')
            : tr('payment.recovery.dismiss'),
        onAction: () {
          setState(() => _result = null);
          widget.onViewDetails?.call(pending);
        },
      );
    });
  }

  String _title({required bool paid, required bool coldStart}) {
    if (paid) {
      return coldStart
          ? tr('payment.recovery.cold_paid_title')
          : tr('payment.recovery.paid_title');
    }
    return coldStart
        ? tr('payment.recovery.cold_pending_title')
        : tr('payment.recovery.pending_title');
  }

  String _body({
    required bool paid,
    required bool coldStart,
    required bool isOrder,
  }) {
    final scope = isOrder ? 'order' : 'account';
    final phase = paid ? 'paid' : 'pending';
    final prefix = coldStart ? 'cold_' : '';
    return tr('payment.recovery.$prefix${phase}_body_$scope');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_busy) _CheckingOverlay(message: tr('payment.recovery.checking')),
        ?_result,
      ],
    );
  }
}

/// Full-screen, non-dismissible scrim with a spinner — shown while the resume
/// poll runs so the customer can't act on a half-settled order.
class _CheckingOverlay extends StatelessWidget {
  const _CheckingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      // Swallows every pointer event so the UI underneath is inert.
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The settled-outcome card. Self-contained (no Navigator/showDialog), so it
/// renders identically over the customer and seller MaterialApps regardless of
/// router shape. The single action button is the only way to dismiss it.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.success,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final bool success;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = success ? scheme.primary : scheme.tertiary;
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: false,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          success
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                          color: accent,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: onAction,
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            actionLabel,
                            style: const TextStyle(
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
            ),
          ),
        ),
      ),
    );
  }
}
