import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/widgets/premium/premium_tokens.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchOrders();
  }

  Future<List<Map<String, dynamic>>> _fetchOrders() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await Supabase.instance.client
        .from('orders')
        .select('id, total_amount, status, delivery_address, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      body: CustomScrollView(
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
                style: PremiumTokens.display(size: 18, letterSpacing: -0.3),
              ),
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: PremiumTokens.accent,
                    ),
                  ),
                );
              }

              final orders = snap.data ?? [];
              if (orders.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyOrders(pt: pt),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: EdgeInsets.only(
                          bottom: i < orders.length - 1 ? 12 : 0),
                      child: _OrderCard(order: orders[i], pt: pt),
                    ),
                    childCount: orders.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order card
// ---------------------------------------------------------------------------

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.pt});

  final Map<String, dynamic> order;
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    final id = order['id'] as String? ?? '';
    final shortId = '#${id.substring(0, 8).toUpperCase()}';
    final rawDate = order['created_at'] as String?;
    final date = rawDate != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(rawDate).toLocal())
        : '—';
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final status = order['status'] as String? ?? 'pending';
    final address = order['delivery_address'] as String? ?? '';

    final statusInfo = _statusInfo(status);

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
          onTap: () {}, // detail screen hookup in future sprint
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status icon circle
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
                // Details
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
                                size: 15,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Status chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
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
                            Icon(
                              Iconsax.location,
                              size: 12,
                              color: pt.greyLight,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: PremiumTokens.body(
                                  size: 12,
                                  color: pt.greyLight,
                                ),
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
                            style: PremiumTokens.body(size: 13, color: pt.grey),
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

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Price formatter
// ---------------------------------------------------------------------------

String _fmtPrice(num value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
