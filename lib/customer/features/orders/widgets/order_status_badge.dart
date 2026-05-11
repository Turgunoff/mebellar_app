import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../../../shared/models/order_status.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status, this.compact = false});

  final OrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = _palette(scheme, status);
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

  ({Color bg, Color fg}) _palette(ColorScheme s, OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => (bg: s.surfaceContainerHighest, fg: s.onSurface),
      OrderStatus.confirmed => (bg: s.tertiaryContainer, fg: s.onTertiaryContainer),
      OrderStatus.preparing => (bg: s.tertiaryContainer, fg: s.onTertiaryContainer),
      OrderStatus.shipped => (bg: s.primaryContainer, fg: s.onPrimaryContainer),
      OrderStatus.delivered => (bg: const Color(0xFFDCEFDC), fg: const Color(0xFF1B5E20)),
      OrderStatus.cancelled => (bg: s.errorContainer, fg: s.onErrorContainer),
    };
  }
}
