import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import 'retry_button.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_outlined,
  });

  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // `error`, not `primary` — this widget renders in both the customer and
    // seller theme, and a brand accent (terracotta / indigo) reads as
    // on-brand rather than "something went wrong". `colorScheme.error` is
    // defined identically (AppColors.danger) on both themes.
    final errorColor = Theme.of(context).colorScheme.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: errorColor),
            ),
            const SizedBox(height: 16),
            Text(
              title ?? tr('network_error.title'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? tr('network_error.message'),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              RetryButton(onPressed: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}
