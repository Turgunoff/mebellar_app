import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../../../shared/models/order.dart';
import '../../../../shared/models/order_status.dart';

class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({
    super.key,
    required this.events,
    required this.currentStatus,
  });

  final List<OrderStatusEvent> events;
  final OrderStatus currentStatus;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd MMM, HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < events.length; i++) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        events[i].status.icon,
                        size: 18,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    if (i != events.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: scheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == events.length - 1 ? 0 : 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('order_status.${events[i].status.code}'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFmt.format(events[i].timestamp.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                              ),
                        ),
                        if (events[i].note != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            events[i].note!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
