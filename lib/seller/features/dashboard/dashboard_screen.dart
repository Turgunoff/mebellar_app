import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../config/app_mode.dart';
import '../../../config/remote_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../customer/features/notifications/cubit/notifications_cubit.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/order_status.dart';
import '../../../shared/widgets/brand_refresh_indicator.dart';
import '../notifications/screens/notifications_screen.dart';
import 'bloc/seller_dashboard_cubit.dart';
import 'data/dashboard_mock.dart';
import 'screens/achievements_screen.dart';
import 'widgets/achievements_strip.dart';
import 'widgets/dashboard_kit.dart';
import 'widgets/hero_sales_card.dart';
import 'widgets/kpi_card.dart';
import 'widgets/seller_leaderboard.dart';
import 'widgets/top_products_card.dart';

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
    final c = SellerColors.of(context);
    return ColoredBox(
      color: c.background,
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
                  child: BrandRefreshIndicator(
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

  // Sections take their own horizontal padding so the achievements strip can
  // scroll edge-to-edge. `_h` wraps the standard 20px-inset blocks.
  static Widget _h(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        // ---- Hero: this-week revenue + sparkline (mock) -------------------
        _h(
          HeroSalesCard(
            weekRevenue: DashboardMock.mockWeekRevenue,
            series: DashboardMock.mockRevenueSeries,
            weekdayLabels: DashboardMock.mockWeekdayLabels,
            deltaPercent: DashboardMock.mockSalesDeltaPercent,
            onTap: () => context.go('/seller/analytics'),
          ),
        ),
        const SizedBox(height: 20),

        // ---- KPI grid (real numbers from the cubit + mock deltas) ---------
        _h(_KpiGrid(data: data)),
        const SizedBox(height: 26),

        // ---- Achievements (mock) — bleeds full-width ----------------------
        _h(
          DashSectionHeader(
            title: 'Yutuqlar',
            subtitle: 'Bosqichlarni bosib oting',
            trailing: _SeeAllButton(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AchievementsScreen(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AchievementsStrip(achievements: DashboardMock.mockAchievements),
        const SizedBox(height: 26),

        // ---- Seller leaderboard (mock) ------------------------------------
        _h(
          const DashSectionHeader(
            title: 'Sotuvchilar reytingi',
            subtitle: 'Bu hafta · savdo bo\'yicha',
          ),
        ),
        const SizedBox(height: 12),
        _h(SellerLeaderboard(entries: DashboardMock.mockLeaderboard)),
        const SizedBox(height: 26),

        // ---- Top products (mock) ------------------------------------------
        _h(
          const DashSectionHeader(
            title: 'Eng ko\'p sotilgan',
            subtitle: 'So\'nggi 30 kun',
          ),
        ),
        const SizedBox(height: 12),
        _h(TopProductsCard(products: DashboardMock.mockTopProducts)),
        const SizedBox(height: 26),

        // ---- Recent orders (real, from the cubit) -------------------------
        _h(const _RecentOrdersHeader()),
        const SizedBox(height: 12),
        if (data.hasRecentOrders)
          for (var i = 0; i < data.recentOrders.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _h(_RecentOrderTile(order: data.recentOrders[i])),
          ]
        else
          _h(const _EmptyOrdersView()),
      ],
    );
  }
}

/// "Hammasi →" text button used in section headers to open a fuller screen.
class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hammasi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DashKit.indigo,
                  height: 1.0,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: DashKit.indigo,
              ),
            ],
          ),
        ),
      ),
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
    final c = SellerColors.of(context);
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: c.grey,
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
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
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
    final c = SellerColors.of(context);
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
              Icon(Iconsax.notification, size: 24, color: c.ink),
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
                      border: Border.all(color: c.background, width: 1.5),
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
    final tariffEnabled = RemoteConfig.instance.tariffEnabled;
    final exceeded = tariffEnabled && data.productLimitExceeded;
    // Active-product quota: "N / cap" for capped plans, plain "N" when the
    // plan is unlimited (or tariffs are off). Subtitle shows the real plan.
    final productsValue = tariffEnabled && !data.plan.isUnlimited
        ? '${data.productsCount} / ${data.productLimit}'
        : '${data.productsCount}';
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Flatter than 1:1 so the tiles stay compact — the card content (icon
      // row + label + value) is short, so the old square left dead space.
      childAspectRatio: 1.32,
      children: [
        SellerKpiCard(
          icon: Iconsax.wallet_2,
          title: 'Bugungi savdo',
          value: _formatMoney(data.todaysSales),
          unit: 'UZS',
          accentValue: true,
          important: true,
          delta: DashboardMock.mockKpiDeltas['revenue'],
        ),
        SellerKpiCard(
          icon: Iconsax.shopping_bag,
          title: 'Bugungi orderlar',
          value: '${data.todaysOrders}',
          delta: DashboardMock.mockKpiDeltas['orders'],
        ),
        SellerKpiCard(
          icon: Iconsax.clock,
          title: 'Kutayotgan',
          value: '${data.pendingOrders}',
          // A drop in pending orders is the good outcome.
          delta: DashboardMock.mockKpiDeltas['pending'],
          deltaLowerIsBetter: true,
        ),
        SellerKpiCard(
          icon: Iconsax.box,
          title: 'Mahsulotlar',
          // With tariff off there's no quota — show a plain product count.
          value: productsValue,
          subtitle: tariffEnabled ? '${data.plan.label} tarif' : null,
          indicator: exceeded ? KpiIndicator.accent('Limit oshdi') : null,
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
    final c = SellerColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            "So'nggi buyurtmalar",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.ink,
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
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(order.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.grey,
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'UZS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: c.greyMid,
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
    'yan',
    'fev',
    'mar',
    'apr',
    'may',
    'iyn',
    'iyl',
    'avg',
    'sen',
    'okt',
    'noy',
    'dek',
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
        AppColors.sellerPositive,
        AppColors.sellerPositiveBg,
      ),
      OrderStatus.shipped || OrderStatus.preparing => (
        AppColors.sellerProgress,
        AppColors.sellerProgressBg,
      ),
      OrderStatus.cancelled => (
        AppColors.sellerNegative,
        AppColors.sellerNegativeBg,
      ),
      OrderStatus.pending || OrderStatus.confirmed => (
        AppColors.sellerWarning,
        AppColors.sellerWarningBg,
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
    final c = SellerColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: c.surface,
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
          Text(
            "Hozircha buyurtmalar yo'q",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.ink,
              height: 1.2,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Katalogingizga mahsulot qo'shing va birinchi savdoning "
            "zavqini his qiling!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.grey,
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
    final c = SellerColors.of(context);
    return Shimmer.fromColors(
      baseColor: c.fillSoft,
      highlightColor: c.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Hero card
          const _ShimmerBox(height: 188, radius: 24),
          const SizedBox(height: 20),
          // KPI grid
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.32,
            children: List.generate(
              4,
              (_) => const _ShimmerBox(height: double.infinity, radius: 16),
            ),
          ),
          const SizedBox(height: 26),
          // Achievements strip
          const _ShimmerBox(width: 160, height: 20, radius: 6),
          const SizedBox(height: 12),
          Row(
            children: const [
              _ShimmerBox(width: 116, height: 122, radius: 18),
              SizedBox(width: 12),
              _ShimmerBox(width: 116, height: 122, radius: 18),
              SizedBox(width: 12),
              Expanded(child: _ShimmerBox(height: 122, radius: 18)),
            ],
          ),
          const SizedBox(height: 26),
          // Leaderboard
          const _ShimmerBox(width: 190, height: 20, radius: 6),
          const SizedBox(height: 12),
          const _ShimmerBox(height: 260, radius: 20),
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
    final c = SellerColors.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
