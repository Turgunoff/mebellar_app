import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../config/app_mode.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../customer/features/notifications/cubit/notifications_cubit.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/order_status.dart';
import '../notifications/screens/notifications_screen.dart';
import 'bloc/seller_dashboard_cubit.dart';
import 'widgets/kpi_card.dart';

// Typography note for this screen:
//
//   Plus Jakarta Sans is the seller mode's universal font — it's wired into
//   the theme via `AppTypography.plusJakartaSansTextTheme(...)` in
//   `seller_theme.dart`. Every `TextStyle` below intentionally omits
//   `fontFamily` so the family is inherited from that theme.
//
//   The single intentional exception is the "Barchasi" CTA in
//   `_RecentOrdersHeader`, where the design uses Manrope to give the
//   trailing action a quieter, more utilitarian feel against the bold
//   Jakarta section header.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);

// =============================================================================
// Screen
// =============================================================================
class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key, this.onSeeAllOrders});

  /// Kept for source-compatibility with `SellerHomeShell` — the "Barchasi"
  /// CTA was removed from the recent-orders header, so the callback is no
  /// longer invoked. Safe to drop once the shell stops passing it.
  final VoidCallback? onSeeAllOrders;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SellerDashboardCubit>(
      create: (_) => sl<SellerDashboardCubit>()..load(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<SellerDashboardCubit, SellerDashboardState>(
          builder: (context, state) {
            return Column(
              children: [
                // Fixed header — never scrolls with the content below.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: _GreetingHeader(
                    sellerName: state.data.displaySellerName,
                    shopName: state.data.shopName,
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.sellerPrimary,
                    onRefresh: () =>
                        context.read<SellerDashboardCubit>().refresh(),
                    child: state.isLoading
                        ? const _DashboardSkeleton()
                        : _DashboardContent(data: state.data),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data});

  final SellerDashboardData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _KpiGrid(data: data),
        const SizedBox(height: 28),
        const _RecentOrdersHeader(),
        const SizedBox(height: 12),
        if (data.hasRecentOrders)
          for (var i = 0; i < data.recentOrders.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _RecentOrderTile(order: data.recentOrders[i]),
          ]
        else
          const _EmptyOrdersView(),
      ],
    );
  }
}

// =============================================================================
// 1. Personalised greeting header (replaces the old "Boshqaruv" AppBar)
//
// Row 1: large welcome line + notification bell (right).
// Row 2: subtle subtitle binding the metrics to the shop name.
// =============================================================================
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.sellerName, required this.shopName});

  final String sellerName;
  final String? shopName;

  @override
  Widget build(BuildContext context) {
    final shopLabel = (shopName == null || shopName!.trim().isEmpty)
        ? "Do'koningiz"
        : shopName!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Salom, $sellerName! 👋',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  height: 1.2,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const _NotificationBell(),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "$shopLabel do'koni ko'rsatkichlari",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _grey,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  /// Counts unread rows whose `targetMode` is seller. Matches the filter the
  /// seller inbox screen applies, so the badge and the list agree.
  static int _sellerUnread(NotificationsState state) {
    return state.items
        .where((n) => !n.isRead && n.kind.targetMode == AppMode.seller)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    if (!sl.isRegistered<NotificationsCubit>()) {
      return _BellShell(onTap: () => _open(context), unreadCount: 0);
    }
    return BlocProvider<NotificationsCubit>.value(
      value: sl<NotificationsCubit>(),
      child: BlocBuilder<NotificationsCubit, NotificationsState>(
        buildWhen: (a, b) => _sellerUnread(a) != _sellerUnread(b),
        builder: (context, state) => _BellShell(
          onTap: () => _open(context),
          unreadCount: _sellerUnread(state),
        ),
      ),
    );
  }
}

class _BellShell extends StatelessWidget {
  const _BellShell({required this.onTap, required this.unreadCount});

  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(Iconsax.notification, size: 24, color: _ink),
              if (unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sellerPrimary,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: AppColors.lightBackground,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2. KPI grid
// =============================================================================
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});

  final SellerDashboardData data;

  @override
  Widget build(BuildContext context) {
    final exceeded = data.productLimitExceeded;
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.05,
      children: [
        SellerKpiCard(
          icon: Iconsax.wallet_2,
          title: 'Bugungi savdo',
          value: _formatMoney(data.todaysSales),
          unit: 'UZS',
          accentValue: true,
          important: true,
        ),
        SellerKpiCard(
          icon: Iconsax.shopping_bag,
          title: 'Bugungi orderlar',
          value: '${data.todaysOrders}',
        ),
        SellerKpiCard(
          icon: Iconsax.clock,
          title: 'Kutayotgan',
          value: '${data.pendingOrders}',
        ),
        SellerKpiCard(
          icon: Iconsax.box,
          title: 'Mahsulotlar',
          value: '${data.productsCount} / ${data.productLimit}',
          subtitle: 'Standard tarif',
          indicator: exceeded ? KpiIndicator.terracotta('Limit oshdi') : null,
        ),
      ],
    );
  }
}

String _formatMoney(num amount) {
  final whole = amount.toInt();
  final s = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

// =============================================================================
// 4. Recent orders header
// =============================================================================
class _RecentOrdersHeader extends StatelessWidget {
  const _RecentOrdersHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: Text(
            "So'nggi buyurtmalar",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#${order.orderNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(order.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _grey,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _StatusPill(status: order.status),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatMoney(order.grandTotal),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'UZS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _greyMid,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  const months = [
    'yan', 'fev', 'mar', 'apr', 'may', 'iyn',
    'iyl', 'avg', 'sen', 'okt', 'noy', 'dek',
  ];
  final day = dt.day.toString().padLeft(2, '0');
  final mon = months[dt.month - 1];
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$day $mon • $hh:$mm';
}

// =============================================================================
// 5. Status pill
// =============================================================================
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = _styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.$2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _labelFor(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: theme.$1,
          height: 1.0,
        ),
      ),
    );
  }

  static (Color, Color) _styleFor(OrderStatus s) {
    return switch (s) {
      OrderStatus.delivered => (
          Color(0xFF1F6B49),
          Color(0xFFDCF1E5),
        ),
      OrderStatus.shipped || OrderStatus.preparing => (
          Color(0xFF5B21B6),
          Color(0xFFEDE3FF),
        ),
      OrderStatus.cancelled => (
          Color(0xFFC0392B),
          Color(0xFFFDECEA),
        ),
      OrderStatus.pending || OrderStatus.confirmed => (
          Color(0xFF8C5A12),
          Color(0xFFFFF1D6),
        ),
    };
  }

  static String _labelFor(OrderStatus s) => switch (s) {
        OrderStatus.pending => 'Kutilmoqda',
        OrderStatus.confirmed => 'Tasdiqlangan',
        OrderStatus.preparing => 'Tayyorlanmoqda',
        OrderStatus.shipped => "Yo'lda",
        OrderStatus.delivered => 'Yetkazildi',
        OrderStatus.cancelled => 'Bekor qilingan',
      };
}

// =============================================================================
// 6. Zero state
// =============================================================================
class _EmptyOrdersView extends StatelessWidget {
  const _EmptyOrdersView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.sellerPrimary.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.sellerPrimaryTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: AppColors.sellerPrimaryDeep,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Hozircha buyurtmalar yo'q",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
              height: 1.2,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Katalogingizga mahsulot qo'shing va birinchi savdoning "
            "zavqini his qiling!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _grey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 7. Loading skeleton
// =============================================================================
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.shade300;
    final highlight = Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.05,
            children: List.generate(
              4,
              (_) => const _ShimmerBox(height: double.infinity, radius: 16),
            ),
          ),
          const SizedBox(height: 28),
          _ShimmerBox(width: 200, height: 20, radius: 6),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            const _ShimmerBox(height: 84, radius: 16),
          ],
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({this.width, required this.height, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
