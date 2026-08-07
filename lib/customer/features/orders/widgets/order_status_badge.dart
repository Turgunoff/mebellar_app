import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../../../shared/models/order_status.dart';
import '../../../../core/theme/premium_tokens.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final OrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pt = PremiumTokens.of(context);
    final palette = _palette(scheme, pt, status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 14 : 16, color: palette.fg),
          const SizedBox(width: 4),
          Text(
            tr('order_status.${status.code}'),
            style: TextStyle(
              color: palette.fg,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 13,
            ),
          ),
        ],
      ),
    );
  }

  ({Color bg, Color fg}) _palette(
    ColorScheme s,
    PremiumTokens pt,
    OrderStatus status,
  ) {
    return switch (status) {
      OrderStatus.pending => (bg: s.surfaceContainerHighest, fg: s.onSurface),
      OrderStatus.awaitingPayment => (
        bg: pt.warningBg,
        fg: pt.onWarningBg,
      ),
      OrderStatus.confirmed => (
        bg: s.tertiaryContainer,
        fg: s.onTertiaryContainer,
      ),
      OrderStatus.preparing => (
        bg: s.tertiaryContainer,
        fg: s.onTertiaryContainer,
      ),
      OrderStatus.shipped => (bg: s.primaryContainer, fg: s.onPrimaryContainer),
      OrderStatus.delivered => (bg: pt.successBg, fg: pt.onSuccessBg),
      OrderStatus.cancelled => (bg: s.errorContainer, fg: s.onErrorContainer),
    };
  }
}
