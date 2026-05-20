import 'package:cached_network_image/cached_network_image.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/repositories/order_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/error_state.dart';
import '../bloc/order_detail_bloc.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/order_status_timeline.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrderDetailBloc(sl<OrderRepository>())
        ..add(OrderDetailRequested(id)),
      child: const _OrderDetailView(),
    );
  }
}

class _OrderDetailView extends StatelessWidget {
  const _OrderDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrderDetailBloc, OrderDetailState>(
      listenWhen: (a, b) => a.error != b.error && b.error != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error ?? tr('error.unknown'))),
        );
      },
      builder: (context, state) {
        if (state.status == OrderDetailStatus.initial ||
            state.status == OrderDetailStatus.loading) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: BrandLoadingIndicator()),
          );
        }
        if (state.status == OrderDetailStatus.failure ||
            state.order == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorState(message: state.error),
          );
        }
        return _Body(state: state);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});
  final OrderDetailState state;

  @override
  Widget build(BuildContext context) {
    final order = state.order!;
    final lang = context.locale.languageCode;
    final priceFormat = NumberFormat('#,###', lang);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber),
        actions: [
          if (state.realtimeConnected)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr('orders.realtime'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              OrderStatusBadge(status: order.status),
              const Spacer(),
              if (order.expectedDeliveryAt != null)
                Text(
                  tr('orders.expected', args: [
                    DateFormat('dd MMM', lang)
                        .format(order.expectedDeliveryAt!.toLocal())
                  ]),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tr('orders.timeline'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          OrderStatusTimeline(
            events: order.timeline,
            currentStatus: order.status,
          ),
          const SizedBox(height: 24),
          // Items
          Text(tr('orders.items'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        order.shop.name.get(lang),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const Divider(),
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: item.thumbnail.isEmpty
                                  ? const ColoredBox(color: Color(0x11000000))
                                  : CachedNetworkImage(
                                      imageUrl: item.thumbnail,
                                      // ROADMAP B.7 — 48px order-item thumbnail.
                                      memCacheWidth: 150,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName.get(lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.quantity} Г— ${priceFormat.format(item.unitPrice)}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${priceFormat.format(item.lineTotal)} so\'m',
                            style:
                                Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Address
          Text(tr('checkout.delivery_address'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(order.address.label),
              subtitle: Text(
                [
                  if (order.address.recipientName.isNotEmpty)
                    order.address.recipientName,
                  if (order.address.phone.isNotEmpty) order.address.phone,
                  order.address.formatted(lang),
                ].join('\n'),
              ),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 16),
          // Totals
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _row(context, tr('checkout.items_total'),
                      '${priceFormat.format(order.itemsTotal)} so\'m'),
                  const SizedBox(height: 6),
                  _row(context, tr('checkout.delivery_fee'),
                      '${priceFormat.format(order.deliveryFee)} so\'m'),
                  const Divider(),
                  _row(
                    context,
                    tr('checkout.total'),
                    '${priceFormat.format(order.grandTotal)} so\'m',
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
          if (order.cancelReason != null) ...[
            const SizedBox(height: 16),
            Card(
              color: scheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.cancel_outlined,
                    color: scheme.onErrorContainer),
                title: Text(tr('orders.cancel_reason'),
                    style: TextStyle(color: scheme.onErrorContainer)),
                subtitle: Text(order.cancelReason!,
                    style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ),
          ],
          if (order.status.cancellable) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _confirmCancel(context),
              icon: Icon(Icons.cancel_outlined, color: scheme.error),
              label: Text(
                tr('orders.cancel'),
                style: TextStyle(color: scheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: scheme.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.go('/orders'),
            icon: const Icon(Icons.list_alt),
            label: Text(tr('orders.title')),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool isBold = false}) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
        );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }

  void _confirmCancel(BuildContext context) {
    final reasonCtrl = TextEditingController();
    final bloc = context.read<OrderDetailBloc>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('orders.cancel_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('orders.cancel_subtitle')),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: tr('orders.cancel_reason_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim().isEmpty
                  ? tr('orders.cancel_reason_default')
                  : reasonCtrl.text.trim();
              bloc.add(OrderDetailCancelled(reason));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(tr('orders.cancel')),
          ),
        ],
      ),
    );
  }
}

