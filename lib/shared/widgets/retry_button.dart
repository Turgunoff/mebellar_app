import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

/// The single "retry" action for a failed load — used inside [ErrorState] and
/// anywhere else an inline retry affordance is needed.
///
/// Deliberately theme-agnostic: it inherits `FilledButtonThemeData` from the
/// active [Theme], so it renders correctly in both the customer (terracotta)
/// and seller (indigo) mode without importing either mode's token bag.
class RetryButton extends StatelessWidget {
  const RetryButton({super.key, required this.onPressed, this.label});

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh),
      label: Text(label ?? tr('common.retry')),
    );
  }
}
