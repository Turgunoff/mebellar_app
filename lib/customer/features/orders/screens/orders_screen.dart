import 'package:cached_network_image/cached_network_image.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/repositories/order_repository.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../bloc/orders_bloc.dart';
import '../widgets/order_status_badge.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrdersBloc(sl<OrderRepository>())
        ..add(const OrdersRequested()),
      child: const _OrdersView(),
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: OrdersTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('orders.title')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (i) => context
                .read<OrdersBloc>()
                .add(OrdersTabChanged(OrdersTab.values[i])),
            tabs: [
              for (final t in OrdersTab.values)
                Tab(text: tr('orders.tab_${t.name}')),
            ],
          ),
        ),
        body: BlocBuilder<OrdersBloc, OrdersState>(
          builder: (context, state) {
            return switch (state.status) {
              OrdersStatus.initial ||
              OrdersStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              OrdersStatus.failure => ErrorState(
                  message: state.error,
                  onRetry: () => context
                      .read<OrdersBloc>()
                      .add(const OrdersRequested()),
                ),
              OrdersStatus.ready => RefreshIndicator(
                  onRefresh: () async => context
                      .read<OrdersBloc>()
                      .add(const OrdersRequested()),
                  child: state.visibleOrders.isEmpty
                      ? Stack(
                          children: [
                            ListView(),
                            EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: tr('orders.empty'),
                              message: tr('orders.empty_hint'),
                              action: () => context.go('/categories'),
                              actionLabel: tr('catalog.title'),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: state.visibleOrders.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) =>
                              _OrderTile(order: state.visibleOrders[i]),
                        ),
                ),
            };
          },
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final priceFormat = NumberFormat('#,###', lang);
    final dateFmt = DateFormat('dd MMM', lang);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OrderStatusBadge(status: order.status, compact: true),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 14, color: scheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.shop.name.get(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    dateFmt.format(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < order.items.length && i < 3; i++) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: order.items[i].thumbnail.isEmpty
                            ? ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: const Icon(Icons.image_outlined,
                                    size: 18),
                              )
                            : CachedNetworkImage(
                                imageUrl: order.items[i].thumbnail,
                                // ROADMAP B.7 — 48px order-item thumbnail.
                                memCacheWidth: 150,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    if (i < order.items.length - 1 && i < 2)
                      const SizedBox(width: 6),
                  ],
                  if (order.items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '+${order.items.length - 3}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '${priceFormat.format(order.grandTotal)} so\'m',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
