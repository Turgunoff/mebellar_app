import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/profile_orders_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
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
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 110,
                backgroundColor: pt.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                foregroundColor: pt.dark,
                leading: IconButton(
                  icon: Icon(Iconsax.arrow_left, color: pt.dark),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding:
                      const EdgeInsetsDirectional.only(start: 20, bottom: 14),
                  expandedTitleScale: 1.4,
                  title: Text(
                    'Mening buyurtmalarim',
                    style:
                        PremiumTokens.display(size: 18, letterSpacing: -0.3),
                  ),
                ),
              ),
              if (state.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: BrandLoadingIndicator(
                      color: PremiumTokens.accent,
                    ),
                  ),
                )
              else if (state.orders.isEmpty)
                SliverFillRemaining(child: _EmptyOrders(pt: pt))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final order = state.orders[i];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i < state.orders.length - 1 ? 12 : 0,
                          ),
                          child: _OrderCard(
                            order: order,
                            pt: pt,
                            onCancel: (reason) =>
                                ctx.read<ProfileOrdersCubit>().cancelOrder(
                                  order['id'] as String,
                                  reason,
                                ),
                          ),
                        );
                      },
                      childCount: state.orders.length,
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

  static const _cancellableStatuses = {'pending', 'processing'};

  @override
  Widget build(BuildContext context) {
    final id = order['id'] as String? ?? '';
    final shortId = '#${id.substring(0, 8).toUpperCase()}';
    final rawDate = order['created_at'] as String?;
    final date = rawDate != null
        ? DateFormat('dd MMM yyyy, HH:mm')
            .format(DateTime.parse(rawDate).toLocal())
        : '—';
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final status = order['status'] as String? ?? 'pending';
    final address = order['delivery_address'] as String? ?? '';
    final canCancel = _cancellableStatuses.contains(status);
    final statusInfo = _statusInfo(status);
    final feePending =
        order['fee_adjustment_status'] == 'pending_customer' &&
        order['proposed_delivery_fee'] != null;

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusInfo.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusInfo.icon, size: 22, color: statusInfo.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shortId,
                              style: PremiumTokens.body(
                                  size: 15, weight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusInfo.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusInfo.label,
                              style: PremiumTokens.body(
                                size: 11,
                                weight: FontWeight.w700,
                                color: statusInfo.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        date,
                        style: PremiumTokens.body(size: 12, color: pt.grey),
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Iconsax.location,
                                size: 12, color: pt.greyLight),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: PremiumTokens.body(
                                    size: 12, color: pt.greyLight),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Divider(color: pt.divider, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Jami summa',
                            style:
                                PremiumTokens.body(size: 13, color: pt.grey),
                          ),
                          const Spacer(),
                          Text(
                            '${_fmtPrice(total)} UZS',
                            style: PremiumTokens.body(
                              size: 15,
                              weight: FontWeight.w700,
                              color: PremiumTokens.accent,
                            ),
                          ),
                        ],
                      ),
                      if (feePending) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8EE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFFFD580), width: 1),
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
                        ),
                      ],
                      if (canCancel) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _CancelButton(
                            pt: pt,
                            onConfirm: onCancel,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({IconData icon, Color color, String label}) _statusInfo(String status) {
    return switch (status) {
      'pending' => (
          icon: Iconsax.clock,
          color: const Color(0xFFD97706),
          label: 'Kutilmoqda',
        ),
      'processing' || 'tayyorlanmoqda' => (
          icon: Iconsax.box_1,
          color: const Color(0xFF2563EB),
          label: 'Tayyorlanmoqda',
        ),
      'delivering' || 'yolda' => (
          icon: Iconsax.box_time,
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
          color: const Color(0xFFD97706),
          label: status,
        ),
    };
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
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Price formatter
// ─────────────────────────────────────────────────────────────────────────────

String _fmtPrice(num value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
