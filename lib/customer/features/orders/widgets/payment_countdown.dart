import 'dart:async';

import 'package:flutter/material.dart';
import 'package:woody_app/core/i18n/i18n.dart';

import '../../../../core/theme/premium_tokens.dart';

/// Countdown that ticks down from a snapshot taken when the API response
/// arrived — not by re-diffing [DateTime.now()] against [expiresAt] each second.
class PaymentCountdown extends StatefulWidget {
  const PaymentCountdown({
    super.key,
    required this.expiresAt,
    required this.receivedAt,
    this.onExpired,
    this.style,
    this.labelBuilder,
  });

  final DateTime expiresAt;
  final DateTime receivedAt;
  final VoidCallback? onExpired;
  final TextStyle? style;
  final String Function(String formattedTime)? labelBuilder;

  @override
  State<PaymentCountdown> createState() => _PaymentCountdownState();
}

class _PaymentCountdownState extends State<PaymentCountdown> {
  late Duration _initialRemaining;
  final Stopwatch _elapsed = Stopwatch();
  Timer? _timer;
  bool _firedExpired = false;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void didUpdateWidget(covariant PaymentCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt ||
        oldWidget.receivedAt != widget.receivedAt) {
      _resetTimer();
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _firedExpired = false;
    _initialRemaining = widget.expiresAt.difference(widget.receivedAt);
    if (_initialRemaining.isNegative) {
      _initialRemaining = Duration.zero;
    }
    _elapsed
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining <= Duration.zero) {
        _timer?.cancel();
        if (!_firedExpired) {
          _firedExpired = true;
          widget.onExpired?.call();
        }
      }
    });
  }

  Duration get _remaining {
    final left = _initialRemaining - _elapsed.elapsed;
    if (left.isNegative) return Duration.zero;
    return left;
  }

  String _format(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatted = _format(_remaining);
    final text = widget.labelBuilder?.call(formatted) ??
        tr('orders.payment_countdown_label', args: [formatted]);
    return Text(
      text,
      style: widget.style,
    );
  }
}

/// Urgent card shown on order detail while payment is still due.
class PaymentCountdownCard extends StatelessWidget {
  const PaymentCountdownCard({
    super.key,
    required this.expiresAt,
    required this.receivedAt,
    this.onExpired,
  });

  final DateTime expiresAt;
  final DateTime receivedAt;
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pt.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pt.onWarningBg.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('orders.payment_countdown_title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: pt.onWarningBg,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          PaymentCountdown(
            expiresAt: expiresAt,
            receivedAt: receivedAt,
            onExpired: onExpired,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('orders.payment_countdown_subtitle'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
