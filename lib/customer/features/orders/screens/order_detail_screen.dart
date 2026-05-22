import 'package:cached_network_image/cached_network_image.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/models/order.dart'
    show FeeAdjustmentStatus, Order, OrderItem;
import '../../../../shared/models/order_status.dart';
import '../../../../shared/models/review.dart';
import '../../../../shared/repositories/customer_reviews_repository.dart';
import '../../../../shared/repositories/order_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/product_color_chip.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../reviews/widgets/review_composer_sheet.dart';
import '../bloc/order_detail_bloc.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/order_status_timeline.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          OrderDetailBloc(sl<OrderRepository>())..add(OrderDetailRequested(id)),
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
        if (state.status == OrderDetailStatus.failure || state.order == null) {
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
                  tr(
                    'orders.expected',
                    args: [
                      DateFormat(
                        'dd MMM',
                        lang,
                      ).format(order.expectedDeliveryAt!.toLocal()),
                    ],
                  ),
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
          Text(
            tr('orders.items'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                      Icon(
                        Icons.storefront_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
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
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (item.colorSlug.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  ProductColorChip(
                                    slug: item.colorSlug,
                                    swatchSize: 12,
                                    labelStyle: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${priceFormat.format(item.lineTotal)} so\'m',
                            style: Theme.of(context).textTheme.bodyMedium,
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
          Text(
            tr('checkout.delivery_address'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                  _row(
                    context,
                    tr('checkout.items_total'),
                    '${priceFormat.format(order.itemsTotal)} so\'m',
                  ),
                  const SizedBox(height: 6),
                  _row(
                    context,
                    tr('checkout.delivery_fee'),
                    '${priceFormat.format(order.deliveryFee)} so\'m',
                  ),
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
          if (order.feeAdjustmentStatus ==
                  FeeAdjustmentStatus.pendingCustomer &&
              order.proposedDeliveryFee != null) ...[
            const SizedBox(height: 16),
            _FeeAdjustmentBanner(
              state: state,
              proposedFee: order.proposedDeliveryFee!,
              note: order.feeAdjustmentNote,
            ),
          ],
          if (order.cancelReason != null) ...[
            const SizedBox(height: 16),
            Card(
              color: scheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.cancel_outlined,
                  color: scheme.onErrorContainer,
                ),
                title: Text(
                  tr('orders.cancel_reason'),
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
                subtitle: Text(
                  order.cancelReason!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          ],
          // Reviews — kept at the bottom, after the order summary; shown
          // only once the order is delivered.
          if (order.status == OrderStatus.delivered) ...[
            const SizedBox(height: 16),
            _DeliveredReviewsCard(order: order),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
  }) {
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
}

class _FeeAdjustmentBanner extends StatelessWidget {
  const _FeeAdjustmentBanner({
    required this.state,
    required this.proposedFee,
    this.note,
  });

  final OrderDetailState state;
  final num proposedFee;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final priceFormat = NumberFormat('#,###');
    final busy = state.status == OrderDetailStatus.mutating;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD580), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                size: 20,
                color: Color(0xFF8C5A12),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Yetkazish narxi o\'zgardi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8C5A12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sotuvchi yangi yetkazish narxini taklif qildi: '
            '${priceFormat.format(proposedFee)} so\'m',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF5C3A0A),
              height: 1.4,
            ),
          ),
          if (note?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8C5A12),
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => context.read<OrderDetailBloc>().add(
                          const OrderFeeAdjustmentRejected(),
                        ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Rad etish'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: busy ? null : () => _confirmFeeApproval(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2A7D4F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Tasdiqlash'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmFeeApproval(BuildContext context) {
    final priceFormat = NumberFormat('#,###');
    final order = context.read<OrderDetailBloc>().state.order;
    if (order == null) return;
    final newTotal = order.itemsTotal + proposedFee;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yangi narxni tasdiqlash'),
        content: Text(
          'Yetkazish narxi: ${priceFormat.format(proposedFee)} so\'m\n'
          'Jami to\'lov: ${priceFormat.format(newTotal)} so\'m\n\n'
          'Rozilik bildirasizmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor'),
          ),
          FilledButton(
            onPressed: () {
              context.read<OrderDetailBloc>().add(
                const OrderFeeAdjustmentApproved(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Ha, tasdiqlayman'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Delivered-order reviews — rate each purchased product
// ───────────────────────────────────────────────────────────────────────────

class _DeliveredReviewsCard extends StatefulWidget {
  const _DeliveredReviewsCard({required this.order});

  final Order order;

  @override
  State<_DeliveredReviewsCard> createState() => _DeliveredReviewsCardState();
}

class _DeliveredReviewsCardState extends State<_DeliveredReviewsCard> {
  Map<String, Review> _reviews = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<CustomerReviewsRepository>().reviewsForOrder(
      widget.order.id,
    );
    if (!mounted) return;
    result.fold(
      ok: (map) => setState(() {
        _reviews = map;
        _loading = false;
      }),
      err: (_) => setState(() => _loading = false),
    );
  }

  Future<void> _openComposer(OrderItem item) async {
    final review = await showReviewComposer(
      context,
      orderItemId: item.id!,
      orderId: widget.order.id,
      productId: item.productId,
      productName: item.productName.get(context.locale.languageCode),
      thumbnail: item.thumbnail,
      existing: _reviews[item.id],
    );
    final itemId = review?.orderItemId;
    if (itemId != null && mounted) {
      setState(() => _reviews = {..._reviews, itemId: review!});
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order.items.where((it) => it.id != null).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 22,
                  color: Color(0xFFF5A623),
                ),
                const SizedBox(width: 6),
                Text(
                  'Mahsulotlarni baholang',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Fikringiz boshqa xaridorlarga tanlovda yordam beradi.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in items) _itemRow(item, theme),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(OrderItem item, ThemeData theme) {
    final review = _reviews[item.id];
    final fallback = theme.colorScheme.surfaceContainerHighest;
    final comment = review?.comment.trim() ?? '';
    return InkWell(
      onTap: _loading ? null : () => _openComposer(item),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: item.thumbnail.isEmpty
                        ? ColoredBox(color: fallback)
                        : CachedNetworkImage(
                            imageUrl: item.thumbnail,
                            fit: BoxFit.cover,
                            memCacheWidth: 144,
                            placeholder: (_, _) => ColoredBox(color: fallback),
                            errorWidget: (_, _, _) =>
                                ColoredBox(color: fallback),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName.get(context.locale.languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (review != null)
                        StarRating(rating: review.rating.toDouble(), size: 15)
                      else
                        Text(
                          'Hali baholanmagan',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: BrandLoadingIndicator(radius: 8),
                  )
                else if (review != null)
                  Text(
                    'Tahrirlash',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Baholash',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            // Customer's own comment.
            if (comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 60, top: 8),
                child: Text(
                  comment,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
            // Seller's reply, when the shop has answered.
            if (review?.hasReply ?? false)
              Padding(
                padding: const EdgeInsets.only(left: 60, top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fallback,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 13,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Sotuvchi javobi',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        review!.sellerReply!.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
