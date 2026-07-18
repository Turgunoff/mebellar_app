import 'package:cached_network_image/cached_network_image.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/remote_config.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../shared/models/order.dart'
    show FeeAdjustmentStatus, Order, OrderItem;
import '../../../../shared/models/order_status.dart';
import '../../../../shared/models/review.dart';
import '../../../../shared/payments/pending_payment.dart';
import '../../../../shared/payments/pending_payment_service.dart';
import '../../../../shared/repositories/order_repository.dart';
import '../../../../core/result/result.dart';
import '../../../../shared/repositories/payment_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/cancel_reason_sheet.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/product_color_chip.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../home/widgets/premium/premium_tokens.dart';
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
    final pt = PremiumTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber),
        actions: [
          IconButton(
            tooltip: tr('chat.open_for_order'),
            icon: const Icon(Iconsax.message_copy),
            onPressed: () => context.push('/orders/${order.id}/chat'),
          ),
          if (state.realtimeConnected)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: pt.success,
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
      bottomNavigationBar: order.status.awaitsPayment
          ? _PayNowBar(order: order)
          : order.status.customerCancellable
          ? _CancelOrderBar(state: state)
          : null,
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
          _SectionCard(
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
                Divider(color: pt.divider, height: 24),
                for (final item in order.items)
                  InkWell(
                    // Tap a line to open its product page. Disabled only when
                    // the product id is missing (shouldn't happen for a real
                    // order line, but keeps the row inert rather than 404ing).
                    onTap: item.productId.isEmpty
                        ? null
                        : () => context.push('/product/${item.productId}'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: item.thumbnail.isEmpty
                                  ? ColoredBox(color: pt.imageBg)
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
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.quantity} × ${priceFormat.format(item.unitPrice)}',
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
                          const SizedBox(width: 8),
                          Text(
                            tr(
                              'common.sum_suffix',
                              namedArgs: {
                                'value': priceFormat.format(item.lineTotal),
                              },
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Iconsax.arrow_right_3_copy,
                            size: 18,
                            color: pt.greyLight,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Address
          Text(
            tr('checkout.delivery_address'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _SectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 20, color: pt.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.address.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (order.address.recipientName.isNotEmpty)
                            order.address.recipientName,
                          if (order.address.phone.isNotEmpty)
                            order.address.phone,
                          order.address.formatted(lang),
                        ].join('\n'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: pt.grey,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('checkout.step_payment'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _SectionCard(
            child: Column(
              children: [
                _row(
                  context,
                  tr('orders.payment_method'),
                  _paymentProviderLabel(order.paymentProvider),
                ),
                const SizedBox(height: 10),
                _row(
                  context,
                  tr('orders.payment_status'),
                  _paymentStatusLabel(order.paymentStatus),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Totals
          _SectionCard(
            child: Column(
              children: [
                _row(
                  context,
                  tr('checkout.items_total'),
                  '${priceFormat.format(order.itemsTotal)} so\'m',
                ),
                const SizedBox(height: 10),
                _row(
                  context,
                  tr('checkout.delivery_fee'),
                  _deliveryFeeLabel(order, priceFormat),
                ),
                Divider(color: pt.divider, height: 24),
                _row(
                  context,
                  tr('checkout.total'),
                  '${priceFormat.format(order.grandTotal)} so\'m',
                  isBold: true,
                ),
              ],
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

String _paymentProviderLabel(String provider) => switch (provider) {
  'cash' => tr('orders.payment_cash'),
  'payme' => tr('orders.payment_payme'),
  'click' => tr('orders.payment_click'),
  _ => provider,
};

String _paymentStatusLabel(String status) => switch (status) {
  'paid' => tr('orders.payment_paid'),
  'refunded' => tr('orders.payment_refunded'),
  _ => tr('orders.payment_unpaid'),
};

String _deliveryFeeLabel(Order order, NumberFormat priceFormat) {
  if (order.feeAdjustmentStatus == FeeAdjustmentStatus.pendingCustomer &&
      order.proposedDeliveryFee != null) {
    return tr(
      'common.sum_suffix',
      namedArgs: {'value': priceFormat.format(order.proposedDeliveryFee)},
    );
  }
  if (order.deliveryFee > 0) {
    return '${priceFormat.format(order.deliveryFee)} so\'m';
  }
  return tr('checkout.delivery_seller_sets');
}

/// A light, theme-aware container for the order-detail sections. Uses the
/// `surface` token (white in light mode, dark surface in dark mode) with a
/// hairline border + soft shadow, so the section text keeps full contrast in
/// both themes — unlike the brand "inverted" [Card], which is dark in light
/// mode and was rendering dark text on a near-black panel here.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      // Clip the child so an InkWell ripple inside a row stays within the
      // rounded border (the box shadow paints behind the clip, so it survives).
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pt.divider),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Padding(padding: padding, child: child),
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
    final pt = PremiumTokens.of(context);
    final priceFormat = NumberFormat('#,###');
    final busy = state.status == OrderDetailStatus.mutating;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pt.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pt.onWarningBg.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 20,
                color: pt.onWarningBg,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('orders.fee_changed_title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: pt.onWarningBg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'orders.fee_changed_body',
              namedArgs: {'fee': priceFormat.format(proposedFee)},
            ),
            style: TextStyle(fontSize: 13, color: pt.onWarningBg, height: 1.4),
          ),
          if (note?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: TextStyle(
                fontSize: 12,
                color: pt.onWarningBg,
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
                  child: Text(tr('orders.fee_reject')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: busy ? null : () => _confirmFeeApproval(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: PremiumTokens.successStrong,
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
                      : Text(tr('orders.fee_approve')),
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
        title: Text(tr('orders.fee_confirm_title')),
        content: Text(
          tr(
            'orders.fee_confirm_body',
            namedArgs: {
              'fee': priceFormat.format(proposedFee),
              'total': priceFormat.format(newTotal),
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              context.read<OrderDetailBloc>().add(
                const OrderFeeAdjustmentApproved(),
              );
              Navigator.pop(ctx);
            },
            child: Text(tr('orders.fee_confirm_yes')),
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
  /// Reviews the customer submitted in THIS session, keyed by order_item_id.
  /// Lines rated in a previous session arrive already flagged via
  /// `item.reviewed` (backend), so the lock survives a re-open without a fetch.
  final Map<String, Review> _session = {};

  bool _isRated(OrderItem item) =>
      item.reviewed || _session.containsKey(item.id);

  Future<void> _openComposer(OrderItem item) async {
    final review = await showReviewComposer(
      context,
      orderItemId: item.id!,
      orderId: widget.order.id,
      productId: item.productId,
      productName: item.productName.get(context.locale.languageCode),
      thumbnail: item.thumbnail,
    );
    final itemId = review?.orderItemId;
    if (itemId != null && mounted) {
      setState(() => _session[itemId] = review!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order.items.where((it) => it.id != null).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final allRated = items.every(_isRated);

    return _SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                tr('orders.rate_products_title'),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            allRated ? tr('orders.rate_all_done') : tr('orders.rate_prompt'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in items) _itemRow(item, theme),
        ],
      ),
    );
  }

  Widget _itemRow(OrderItem item, ThemeData theme) {
    final sessionReview = _session[item.id];
    final rated = _isRated(item);
    final rating = sessionReview?.rating ?? item.reviewRating ?? 0;
    final fallback = theme.colorScheme.surfaceContainerHighest;
    final comment = sessionReview?.comment.trim() ?? '';
    return InkWell(
      // Rated lines are locked — no re-rating; only un-rated lines open the
      // composer.
      onTap: rated ? null : () => _openComposer(item),
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
                      if (rated)
                        StarRating(rating: rating.toDouble(), size: 15)
                      else
                        Text(
                          tr('orders.not_rated_yet'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (rated)
                  // Locked rated state — disabled, non-tappable "Baholangan".
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr('orders.rated_label'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
                      tr('orders.rate_action'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            // Customer's own comment from this session's submission.
            if (comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 60, top: 8),
                child: Text(
                  comment,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar shown only while the order is still `pending` (customer
/// pending-only cancel rule). Opens the localized reason picker; on confirm it
/// dispatches [OrderDetailCancelled] with the structured code + free text. The
/// reasons list comes straight from the repo (reference data, no bloc state).
class _CancelOrderBar extends StatelessWidget {
  const _CancelOrderBar({required this.state});

  final OrderDetailState state;

  Future<void> _open(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final bloc = context.read<OrderDetailBloc>();
    final selection = await showCancelReasonSheet(
      context: context,
      loadReasons: sl<OrderRepository>().fetchCancelReasons,
      style: CancelReasonStyle(
        surface: scheme.surface,
        ink: scheme.onSurface,
        muted: scheme.onSurfaceVariant,
        border: scheme.outlineVariant,
        field: scheme.surfaceContainerHighest,
        accent: scheme.error,
        danger: scheme.error,
      ),
      labels: CancelReasonLabels(
        title: tr('orders.cancel_title'),
        subtitle: tr('orders.cancel_pick_subtitle'),
        otherHint: tr('orders.cancel_other_hint'),
        confirm: tr('orders.cancel'),
        otherRequired: tr('orders.cancel_other_required'),
        loadError: tr('orders.cancel_load_error'),
      ),
    );
    if (selection == null) return;
    bloc.add(
      OrderDetailCancelled(
        reasonCode: selection.code,
        reasonText: selection.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = state.status == OrderDetailStatus.mutating;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          onPressed: busy ? null : () => _open(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.error,
            side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: scheme.error,
                  ),
                )
              : const Icon(Iconsax.close_circle, size: 18),
          label: Text(tr('orders.cancel')),
        ),
      ),
    );
  }
}

/// Bottom bar shown while an online order is `awaiting_payment`: the seller has
/// set the final delivery fee and the customer now pays the grand total. Mints
/// the provider checkout deep-link (`POST /orders/{id}/pay/{provider}`), marks
/// the pending payment for resume, and hands off to the Payme/Click app.
class _PayNowBar extends StatefulWidget {
  const _PayNowBar({required this.order});

  final Order order;

  @override
  State<_PayNowBar> createState() => _PayNowBarState();
}

class _PayNowBarState extends State<_PayNowBar> {
  bool _busy = false;

  PaymentProvider? get _provider => switch (widget.order.paymentProvider) {
    'payme' => PaymentProvider.payme,
    'click' => PaymentProvider.click,
    _ => null,
  };

  bool get _providerEnabled {
    final provider = _provider;
    if (provider == null) return false;
    return switch (provider) {
      PaymentProvider.payme => RemoteConfig.instance.paymeEnabled,
      PaymentProvider.click => RemoteConfig.instance.clickEnabled,
    };
  }

  Future<void> _pay() async {
    final provider = _provider;
    if (provider == null || _busy || !_providerEnabled) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await sl<PaymentRepository>().checkoutUrl(
        orderId: widget.order.id,
        provider: provider,
      );
      switch (result) {
        case Err(:final failure):
          messenger.showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        case Ok(:final value):
          if (sl.isRegistered<PendingPaymentService>()) {
            await sl<PendingPaymentService>().mark(
              kind: PendingPaymentKind.order,
              reference: widget.order.id,
            );
          }
          final uri = Uri.tryParse(value.checkoutUrl);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
      }
    } catch (e) {
      // launchUrl / PendingPaymentService.mark can still throw; the repo call
      // itself no longer does (its failure arrives as an Err above).
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pt = PremiumTokens.of(context);
    final total = NumberFormat('#,###').format(widget.order.grandTotal);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('orders.pay_total_label'),
                  style: PremiumTokens.body(size: 11, color: pt.greyLight),
                ),
                Text(
                  "$total so'm",
                  style: PremiumTokens.body(size: 16, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_providerEnabled)
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _busy ? null : _pay,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Iconsax.card, size: 18),
                label: Text(tr('orders.pay_now')),
              ),
            )
          else
            Expanded(
              child: Text(
                tr('orders.payment_provider_unavailable'),
                style: PremiumTokens.body(size: 12, color: pt.greyLight),
              ),
            ),
        ],
      ),
    );
  }
}
