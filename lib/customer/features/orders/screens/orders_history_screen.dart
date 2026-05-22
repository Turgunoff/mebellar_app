import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/profile_orders_cubit.dart';

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
      _OrderFilter.active => status == 'pending' ||
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
                  .where(
                      (o) => f.matches(o['status'] as String? ?? 'pending'))
                  .length,
          };
          final visible = orders
              .where(
                  (o) => _filter.matches(o['status'] as String? ?? 'pending'))
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
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: firstLoad
                    ? const Center(
                        child: BrandLoadingIndicator(
                            color: PremiumTokens.accent),
                      )
                    : BrandRefreshIndicator(
                        onRefresh: () =>
                            ctx.read<ProfileOrdersCubit>().fetch(),
                        color: PremiumTokens.accent,
                        child: orders.isEmpty
                            ? _ScrollableCenter(child: _EmptyOrders(pt: pt))
                            : visible.isEmpty
                                ? _ScrollableCenter(
                                    child: _FilterEmpty(
                                        pt: pt, filter: _filter))
                                : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 16, 16, 32),
                                    itemCount: visible.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (_, i) {
                                      final order = visible[i];
                                      return _OrderCard(
                                        order: order,
                                        pt: pt,
                                        onCancel: (reason) => ctx
                                            .read<ProfileOrdersCubit>()
                                            .cancelOrder(
                                                order['id'] as String,
                                                reason),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toolbar — back button.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _CircleIconButton(
                icon: Iconsax.arrow_left,
                onTap: onBack,
                pt: pt,
              ),
            ),
            // Title + order count.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mening buyurtmalarim',
                    style: PremiumTokens.display(
                        size: 24, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    orderCount == 0
                        ? 'Buyurtmalar tarixi'
                        : '$orderCount ta buyurtma',
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 14),
            ] else
              const SizedBox(height: 18),
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
                      horizontal: 6, vertical: 1.5),
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
  final Future<void> Function(String reason) onCancel;

  /// Statuses the customer is still allowed to cancel — mirrors
  /// `OrderStatus.cancellable` (pending · confirmed).
  static const _cancellableStatuses = {'pending', 'confirmed'};

  @override
  Widget build(BuildContext context) {
    final id = order['id'] as String? ?? '';
    final shortId =
        id.length >= 8 ? 'M-${id.substring(0, 8).toUpperCase()}' : 'M-$id';
    final date = _fmtDate(order['created_at'] as String?);
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final status = order['status'] as String? ?? 'pending';
    final address = order['delivery_address'] as String? ?? '';
    final canCancel = _cancellableStatuses.contains(status);
    final st = _statusInfo(status);
    final feePending = order['fee_adjustment_status'] == 'pending_customer' &&
        order['proposed_delivery_fee'] != null;

    final items = (order['order_items'] as List?) ?? const [];
    // A delivered order with at least one un-reviewed line surfaces the
    // "rate your products" call-to-action. `reviews` embeds as a single
    // object (or null) because `reviews.order_item_id` is a UNIQUE column,
    // so PostgREST treats it as a to-one relationship — `null` ⇒ unreviewed.
    final needsReview = status == 'delivered' &&
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
                      Icon(Iconsax.location,
                          size: 14, color: pt.greyLight),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          address,
                          style: PremiumTokens.body(
                              size: 12.5, color: pt.grey),
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
    _ => (
        icon: Iconsax.clock,
        color: const Color(0xFF757575),
        label: status,
      ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD580)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined,
              size: 15, color: Color(0xFF8C5A12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Yetkazish narxi o\'zgardi — tasdiqlash kerak',
              style: PremiumTokens.body(
                size: 12,
                weight: FontWeight.w600,
                color: const Color(0xFF8C5A12),
              ),
            ),
          ),
          const Icon(Iconsax.arrow_right_3,
              size: 13, color: Color(0xFF8C5A12)),
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
            const Icon(Icons.star_rounded,
                size: 18, color: PremiumTokens.accent),
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
            const Icon(Iconsax.arrow_right_3,
                size: 14, color: PremiumTokens.accent),
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
  final Future<void> Function(String reason) onConfirm;

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  bool _busy = false;

  Future<void> _open() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CancellationSheet(pt: widget.pt),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onConfirm(reason);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: Center(
          child: BrandLoadingIndicator(
            color: Color(0xFFDC2626),
            radius: 8,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          'Bekor qilish',
          style: PremiumTokens.body(
            size: 12,
            weight: FontWeight.w600,
            color: const Color(0xFFDC2626),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cancellation bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CancellationSheet extends StatefulWidget {
  const _CancellationSheet({required this.pt});

  final PremiumTokens pt;

  @override
  State<_CancellationSheet> createState() => _CancellationSheetState();
}

class _CancellationSheetState extends State<_CancellationSheet> {
  static const _reasons = [
    'Fikrimdan qaytdim',
    'Manzilni xato kiritdim',
    'Boshqa mebel topdim',
    'Kutish vaqti juda uzoq',
    'Boshqa',
  ];

  String? _selected;

  @override
  Widget build(BuildContext context) {
    final pt = widget.pt;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: pt.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.close_circle,
                  size: 20,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Buyurtmani bekor qilish',
                style: PremiumTokens.display(size: 18, letterSpacing: -0.3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Text(
              'Bekor qilish sababini tanlang',
              style: PremiumTokens.body(size: 13, color: pt.grey),
            ),
          ),
          const SizedBox(height: 20),
          ..._reasons.map((reason) => _ReasonRow(
                reason: reason,
                selected: _selected == reason,
                pt: pt,
                onTap: () => setState(() => _selected = reason),
              )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                disabledBackgroundColor:
                    const Color(0xFFDC2626).withValues(alpha: 0.35),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Bekor qilishni tasdiqlash',
                style: PremiumTokens.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.pt,
    required this.onTap,
  });

  final String reason;
  final bool selected;
  final PremiumTokens pt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFDC2626).withValues(alpha: 0.06)
              : pt.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFDC2626).withValues(alpha: 0.4)
                : pt.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason,
                style: PremiumTokens.body(
                  size: 14,
                  weight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? const Color(0xFFDC2626) : pt.dark,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFFDC2626) : pt.greyLight,
                  width: selected ? 5.5 : 1.5,
                ),
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a centred widget in an always-scrollable viewport so pull-to-refresh
/// still works when the list has no rows to show.
class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.pt});

  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: PremiumTokens.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.receipt,
              size: 36,
              color: PremiumTokens.accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Hali buyurtmalar yo\'q',
            style: PremiumTokens.display(size: 20, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'Katalogga o\'tib, birinchi buyurtmangizni\nbering.',
            textAlign: TextAlign.center,
            style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _FilterEmpty extends StatelessWidget {
  const _FilterEmpty({required this.pt, required this.filter});

  final PremiumTokens pt;
  final _OrderFilter filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: pt.imageBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.box_search, size: 28, color: pt.greyLight),
            ),
            const SizedBox(height: 16),
            Text(
              '"${filter.label}" bo\'limida buyurtma yo\'q',
              textAlign: TextAlign.center,
              style: PremiumTokens.body(
                size: 14,
                weight: FontWeight.w600,
                color: pt.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatters
// ─────────────────────────────────────────────────────────────────────────────

const _uzMonths = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
];

/// `2026-05-21T15:32:00Z` → `21-may 2026, 15:32` (local time, Uzbek month).
String _fmtDate(String? raw) {
  if (raw == null) return '—';
  final d = DateTime.tryParse(raw)?.toLocal();
  if (d == null) return '—';
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day}-${_uzMonths[d.month - 1]} ${d.year}, $hh:$mm';
}

/// `7155555` → `7 155 555` (space-grouped, Uzbek convention).
String _fmtPrice(num value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}
