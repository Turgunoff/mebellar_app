import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/cancel_reason_sheet.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/profile_orders_cubit.dart';

part 'orders_history_sheets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Status filter — tabs above the list
// ─────────────────────────────────────────────────────────────────────────────

enum _OrderFilter {
  all('Hammasi'),
  active('Faol'),
  delivered('Yetkazilgan'),
  cancelled('Bekor qilingan');

  const _OrderFilter(this.label);
  final String label;

  /// Whether an order with [status] belongs under this filter. Status codes
  /// mirror `OrderStatus` (pending · confirmed · preparing · shipped ·
  /// delivered · cancelled).
  bool matches(String status) {
    return switch (this) {
      _OrderFilter.all => true,
      _OrderFilter.active =>
        status == 'pending' ||
            status == 'confirmed' ||
            status == 'preparing' ||
            status == 'shipped',
      _OrderFilter.delivered => status == 'delivered',
      _OrderFilter.cancelled => status == 'cancelled',
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  _OrderFilter _filter = _OrderFilter.all;

  @override
  void initState() {
    super.initState();
    // Re-fetch on entry so the list is always fresh when the user navigates
    // here (e.g. from a deep link or after the app resumes).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileOrdersCubit>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      body: BlocBuilder<ProfileOrdersCubit, ProfileOrdersState>(
        builder: (ctx, state) {
          final orders = state.orders;
          // Spinner only on the very first load — once we have orders the
          // list stays visible while pull-to-refresh runs.
          final firstLoad = state.isLoading && orders.isEmpty;

          final counts = {
            for (final f in _OrderFilter.values)
              f: orders
                  .where((o) => f.matches(o['status'] as String? ?? 'pending'))
                  .length,
          };
          final visible = orders
              .where(
                (o) => _filter.matches(o['status'] as String? ?? 'pending'),
              )
              .toList();

          return Column(
            children: [
              _Header(
                pt: pt,
                orderCount: orders.length,
                showFilters: orders.isNotEmpty,
                selected: _filter,
                counts: counts,
                onSelect: (f) => setState(() => _filter = f),
                // After a successful checkout the dialog `context.go('/orders')`s
                // here, leaving a single-entry stack — a bare `Navigator.pop`
                // would be dead. Fall back to home so Back is never trapped.
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              Expanded(
                child: firstLoad
                    ? const Center(
                        child: BrandLoadingIndicator(
                          color: PremiumTokens.accent,
                        ),
                      )
                    : BrandRefreshIndicator(
                        onRefresh: () => ctx.read<ProfileOrdersCubit>().fetch(),
                        color: PremiumTokens.accent,
                        child: orders.isEmpty
                            ? _ScrollableCenter(child: _EmptyOrders(pt: pt))
                            : visible.isEmpty
                            ? _ScrollableCenter(
                                child: _FilterEmpty(pt: pt, filter: _filter),
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  32,
                                ),
                                itemCount: visible.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final order = visible[i];
                                  return _OrderCard(
                                    order: order,
                                    pt: pt,
                                    onCancel: (selection) => ctx
                                        .read<ProfileOrdersCubit>()
                                        .cancelOrder(
                                          order['id'] as String,
                                          reasonCode: selection.code,
                                          reasonText: selection.text,
                                        ),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — fixed top section: back button, title, count, filter chips
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.pt,
    required this.orderCount,
    required this.showFilters,
    required this.selected,
    required this.counts,
    required this.onSelect,
    required this.onBack,
  });

  final PremiumTokens pt;
  final int orderCount;
  final bool showFilters;
  final _OrderFilter selected;
  final Map<_OrderFilter, int> counts;
  final ValueChanged<_OrderFilter> onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toolbar — back button + order-count pill.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Iconsax.arrow_left_2_copy,
                    onTap: onBack,
                    pt: pt,
                  ),
                  const Spacer(),
                  if (orderCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: PremiumTokens.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$orderCount ta',
                        style: PremiumTokens.body(
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: PremiumTokens.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Title + subtitle.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buyurtmalarim',
                    style: PremiumTokens.display(size: 28, letterSpacing: -0.6),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Buyurtmalaringiz tarixi va holati',
                    style: PremiumTokens.body(
                      size: 13,
                      weight: FontWeight.w500,
                      color: pt.grey,
                    ),
                  ),
                ],
              ),
            ),
            // Filter chips.
            if (showFilters) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final f in _OrderFilter.values)
                      _FilterChip(
                        label: f.label,
                        count: counts[f] ?? 0,
                        selected: f == selected,
                        pt: pt,
                        onTap: () => onSelect(f),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.pt,
  });

  final IconData icon;
  final VoidCallback onTap;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pt.imageBg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: pt.dark),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.pt,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final PremiumTokens pt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? PremiumTokens.accent : pt.imageBg,
            borderRadius: BorderRadius.circular(30),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: PremiumTokens.accent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: PremiumTokens.body(
                  size: 13,
                  weight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : pt.dark,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  constraints: const BoxConstraints(minWidth: 19),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : pt.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: PremiumTokens.body(
                      size: 11,
                      weight: FontWeight.w700,
                      color: selected ? Colors.white : pt.grey,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order card
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.pt,
    required this.onCancel,
  });

  final Map<String, dynamic> order;
  final PremiumTokens pt;
  final Future<void> Function(CancelReasonSelection selection) onCancel;

  /// Statuses the customer is still allowed to cancel — mirrors
  /// `OrderStatus.customerCancellable` (pending only). Once the seller
  /// confirms, cancellation is the seller's call (protects logistics costs).
  static const _cancellableStatuses = {'pending'};

  @override
  Widget build(BuildContext context) {
    final id = order['id'] as String? ?? '';
    final shortId = id.length >= 8
        ? 'M-${id.substring(0, 8).toUpperCase()}'
        : 'M-$id';
    final date = _fmtDate(order['created_at'] as String?);
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final status = order['status'] as String? ?? 'pending';
    final address = order['delivery_address'] as String? ?? '';
    final canCancel = _cancellableStatuses.contains(status);
    final st = _statusInfo(status);
    final feePending =
        order['fee_adjustment_status'] == 'pending_customer' &&
        order['proposed_delivery_fee'] != null;

    final items = (order['order_items'] as List?) ?? const [];
    // A delivered order with at least one un-reviewed line surfaces the
    // "rate your products" call-to-action. `reviews` embeds as a single
    // object (or null) because `reviews.order_item_id` is a UNIQUE column,
    // so PostgREST treats it as a to-one relationship — `null` ⇒ unreviewed.
    final needsReview =
        status == 'delivered' &&
        items.any((it) => (it as Map?)?['reviews'] == null);
    final thumbs = items.map<String?>((it) {
      final products = (it as Map?)?['products'];
      final images = products is Map ? products['images'] : null;
      return (images is List && images.isNotEmpty)
          ? images.first as String?
          : null;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pt.divider),
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/orders/$id'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: status pill + order number ──────────────────
                Row(
                  children: [
                    _StatusPill(info: st),
                    const Spacer(),
                    Text(
                      shortId,
                      style: PremiumTokens.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: pt.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Iconsax.calendar_1, size: 13, color: pt.greyLight),
                    const SizedBox(width: 5),
                    Text(
                      date,
                      style: PremiumTokens.body(size: 12, color: pt.grey),
                    ),
                  ],
                ),
                // ── Product thumbnails + count ──────────────────────────
                if (thumbs.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var i = 0; i < thumbs.length && i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        _Thumb(url: thumbs[i], pt: pt),
                      ],
                      const SizedBox(width: 10),
                      Text(
                        thumbs.length > 3
                            ? '+${thumbs.length - 3} ta mahsulot'
                            : '${thumbs.length} ta mahsulot',
                        style: PremiumTokens.body(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: pt.grey,
                        ),
                      ),
                    ],
                  ),
                ],
                // ── Delivery address ────────────────────────────────────
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Iconsax.location, size: 14, color: pt.greyLight),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          address,
                          style: PremiumTokens.body(size: 12.5, color: pt.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Divider(color: pt.divider, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Jami summa',
                      style: PremiumTokens.body(size: 13, color: pt.grey),
                    ),
                    const Spacer(),
                    Text(
                      '${_fmtPrice(total)} UZS',
                      style: PremiumTokens.body(
                        size: 16,
                        weight: FontWeight.w700,
                        color: PremiumTokens.accent,
                      ),
                    ),
                  ],
                ),
                if (needsReview) ...[
                  const SizedBox(height: 12),
                  _RateCta(orderId: id),
                ],
                if (feePending) ...[
                  const SizedBox(height: 12),
                  const _FeePendingBanner(),
                ],
                if (canCancel) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _CancelButton(pt: pt, onConfirm: onCancel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status pill
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.info});

  final ({IconData icon, Color color, String label}) info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 14, color: info.color),
          const SizedBox(width: 5),
          Text(
            info.label,
            style: PremiumTokens.body(
              size: 12,
              weight: FontWeight.w700,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status icon / accent colour / Uzbek label for a raw `orders.status` code.
({IconData icon, Color color, String label}) _statusInfo(String status) {
  return switch (status) {
    'pending' => (
      icon: Iconsax.clock,
      color: const Color(0xFFD97706),
      label: 'Kutilmoqda',
    ),
    'confirmed' => (
      icon: Iconsax.box_tick,
      color: const Color(0xFF4F46E5),
      label: 'Qabul qilindi',
    ),
    'preparing' => (
      icon: Iconsax.box_1,
      color: const Color(0xFF2563EB),
      label: 'Tayyorlanmoqda',
    ),
    'shipped' => (
      icon: Iconsax.truck_fast,
      color: const Color(0xFF0891B2),
      label: "Yo'lda",
    ),
    'delivered' => (
      icon: Iconsax.tick_circle,
      color: const Color(0xFF16A34A),
      label: 'Yetkazilgan',
    ),
    'cancelled' => (
      icon: Iconsax.close_circle,
      color: const Color(0xFFDC2626),
      label: 'Bekor qilingan',
    ),
    _ => (icon: Iconsax.clock, color: const Color(0xFF757575), label: status),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Product thumbnail
// ─────────────────────────────────────────────────────────────────────────────

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.pt});

  final String? url;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: pt.imageBg,
      child: Icon(Iconsax.box, size: 18, color: pt.greyLight),
    );
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: pt.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url == null || url!.isEmpty)
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              memCacheWidth: 138,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fee-adjustment banner
// ─────────────────────────────────────────────────────────────────────────────

class _FeePendingBanner extends StatelessWidget {
  const _FeePendingBanner();

  @override
  Widget build(BuildContext context) {
    final warning = context.customColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: warning.withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, size: 15, color: warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Yetkazish narxi o\'zgardi — tasdiqlash kerak',
              style: PremiumTokens.body(
                size: 12,
                weight: FontWeight.w600,
                color: warning,
              ),
            ),
          ),
          Icon(Iconsax.arrow_right_3_copy, size: 13, color: warning),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rate-your-products CTA — shown on delivered orders with pending reviews
// ─────────────────────────────────────────────────────────────────────────────

class _RateCta extends StatelessWidget {
  const _RateCta({required this.orderId});

  final String orderId;

  /// Opens the order detail (where the per-product rating lives), then
  /// refreshes the list on return so a just-submitted review clears the CTA.
  Future<void> _open(BuildContext context) async {
    await context.push('/orders/$orderId');
    if (context.mounted) context.read<ProfileOrdersCubit>().fetch();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: PremiumTokens.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.star_rounded,
              size: 18,
              color: PremiumTokens.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mahsulotlarni baholang',
                style: PremiumTokens.body(
                  size: 13,
                  weight: FontWeight.w700,
                  color: PremiumTokens.accent,
                ),
              ),
            ),
            const Icon(
              Iconsax.arrow_right_3_copy,
              size: 14,
              color: PremiumTokens.accent,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cancel button — opens the bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CancelButton extends StatefulWidget {
  const _CancelButton({required this.pt, required this.onConfirm});

  final PremiumTokens pt;
  final Future<void> Function(CancelReasonSelection selection) onConfirm;

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  bool _busy = false;

  Future<void> _open() async {
    final cubit = context.read<ProfileOrdersCubit>();
    final selection = await showCancelReasonSheet(
      context: context,
      loadReasons: cubit.cancelReasons,
      style: _customerCancelStyle(context, widget.pt),
      labels: _cancelReasonLabels(),
    );
    if (selection == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onConfirm(selection);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    if (_busy) {
      return SizedBox(
        width: 18,
        height: 18,
        child: Center(child: BrandLoadingIndicator(color: danger, radius: 8)),
      );
    }
    return GestureDetector(
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: danger.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.close_circle, size: 14, color: danger),
            const SizedBox(width: 5),
            Text(
              'Bekor qilish',
              style: PremiumTokens.body(
                size: 12.5,
                weight: FontWeight.w600,
                color: danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
