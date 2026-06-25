import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:woody_app/core/i18n/i18n.dart';

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
import '../tariff/screens/tariff_screen.dart';
import 'bloc/seller_dashboard_cubit.dart';
import 'screens/achievements_screen.dart';
import 'widgets/achievements_strip.dart';
import 'widgets/dashboard_kit.dart';
import 'widgets/hero_sales_card.dart';
import 'widgets/kpi_card.dart';
import 'widgets/seller_leaderboard.dart';
import 'widgets/top_products_card.dart';
import 'widgets/wallet_debt_banner.dart';

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
    return BlocBuilder<SellerDashboardCubit, SellerDashboardState>(
      builder: (context, state) {
        // Debt freeze paints the whole dashboard with a red wash so the
        // critical state is unmissable even before the banner scrolls in.
        final suspended =
            state.data.wallet?.isSuspendedDueToDebt ?? false;
        final background = suspended
            ? Color.alphaBlend(
                AppColors.danger.withValues(alpha: 0.07),
                c.background,
              )
            : c.background;
        // No cached greeting yet and the identity fetch is still in
        // flight — shimmer instead of flashing the "Sotuvchi" default.
        final identityPending =
            state.isLoading &&
            state.data.sellerName == null &&
            state.data.shopName == null;
        return ColoredBox(
          color: background,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Fixed header — never scrolls with the content below.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: identityPending
                      ? const _GreetingHeaderShimmer()
                      : _GreetingHeader(
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
            ),
          ),
        );
      },
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
        // ---- Wallet: balance row / debt-grace warning / freeze alert ------
        if (data.wallet != null) ...[
          _h(WalletDebtBanner(wallet: data.wallet!)),
          const SizedBox(height: 14),
        ],

        // ---- Hero: this-week revenue + sparkline --------------------------
        _h(
          HeroSalesCard(
            weekRevenue: data.weekly.total,
            series: data.weekly.points
                .map((p) => p.amount.toDouble())
                .toList(growable: false),
            weekdayLabels: data.weekly.points
                .map((p) => _uzWeekday(p.date))
                .toList(growable: false),
            deltaPercent: data.weekly.deltaPercent ?? 0,
            onTap: () => context.go('/seller/analytics'),
          ),
        ),
        const SizedBox(height: 20),

        // ---- KPI grid (real numbers + week-over-week deltas) --------------
        _h(_KpiGrid(data: data)),
        const SizedBox(height: 26),

        // ---- Achievements — bleeds full-width -----------------------------
        _h(
          DashSectionHeader(
            title: tr('dashboard.achievements_title'),
            subtitle: tr('dashboard.achievements_subtitle'),
            trailing: _SeeAllButton(
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AchievementsScreen(achievements: data.achievements),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AchievementsStrip(achievements: data.achievements),
        const SizedBox(height: 26),

        // ---- Seller leaderboard -------------------------------------------
        _h(
          DashSectionHeader(
            title: tr('dashboard.leaderboard_title'),
            subtitle: tr('dashboard.leaderboard_subtitle'),
          ),
        ),
        const SizedBox(height: 12),
        _h(SellerLeaderboard(entries: data.leaderboard)),
        const SizedBox(height: 26),

        // ---- Top products (last 30 days) — hidden until there are sales ---
        if (data.topProducts.isNotEmpty) ...[
          _h(
            DashSectionHeader(
              title: tr('dashboard.top_products_title'),
              subtitle: tr('dashboard.last_30_days'),
            ),
          ),
          const SizedBox(height: 12),
          _h(TopProductsCard(products: data.topProducts)),
          const SizedBox(height: 26),
        ],

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('dashboard.see_all'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DashKit.indigo,
                  height: 1.0,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Iconsax.arrow_right_3_copy,
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
        ? tr('dashboard.shop_fallback')
        : shopName!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                tr('dashboard.greeting_hello', namedArgs: {'name': sellerName}),
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
          tr('dashboard.greeting_subtitle', namedArgs: {'name': shopLabel}),
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

/// Greeting placeholder while the identity fetch is in flight. The bell stays
/// live — notifications don't depend on the dashboard snapshot.
class _GreetingHeaderShimmer extends StatelessWidget {
  const _GreetingHeaderShimmer();

  @override
  Widget build(BuildContext context) {
    final c = SellerColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Shimmer.fromColors(
            baseColor: c.fillSoft,
            highlightColor: c.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 22,
                  width: 210,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  height: 13,
                  width: 160,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        const _NotificationBell(),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  void _open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
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
          title: tr('dashboard.kpi_todays_sales'),
          value: _formatMoney(data.todaysSales),
          unit: tr('common.currency_uzs'),
          accentValue: true,
          important: true,
          delta: data.kpiDeltas.revenue,
        ),
        SellerKpiCard(
          icon: Iconsax.shopping_bag,
          title: tr('dashboard.kpi_todays_orders'),
          value: '${data.todaysOrders}',
          delta: data.kpiDeltas.orders,
        ),
        SellerKpiCard(
          icon: Iconsax.clock,
          title: tr('dashboard.kpi_pending'),
          value: '${data.pendingOrders}',
          // A drop in pending orders is the good outcome.
          delta: data.kpiDeltas.pending,
          deltaLowerIsBetter: true,
        ),
        SellerKpiCard(
          icon: Iconsax.box,
          title: tr('dashboard.kpi_products'),
          // With tariff off there's no quota — show a plain product count.
          value: productsValue,
          // Expiring plans (trial bonus / paid) carry their remaining days
          // right on the tile, so the seller sees the runway every day
          // without opening the tariff screen.
          subtitle: !tariffEnabled
              ? null
              : (data.tariffDaysLeft != null
                    ? tr('dashboard.kpi_plan_days_left', namedArgs: {
                        'plan': data.plan.label,
                        'days': data.tariffDaysLeft.toString(),
                      })
                    : tr('dashboard.kpi_plan', namedArgs: {
                        'plan': data.plan.label,
                      })),
          indicator: exceeded
              ? KpiIndicator.accent(tr('dashboard.kpi_limit_exceeded'))
              : null,
          // The card that shows the quota is the shortcut to managing it —
          // especially when "Limit oshdi" is up. No quota with tariff off,
          // so the card stays inert there.
          onTap: tariffEnabled
              ? () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(builder: (_) => const TariffScreen()),
                )
              : null,
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

/// Uzbek 2-letter weekday initial (Mon-anchored) for the hero sparkline labels.
String _uzWeekday(DateTime date) {
  const labels = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  return labels[(date.weekday - 1) % 7];
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
            tr('dashboard.recent_orders'),
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
                tr('common.currency_uzs'),
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
    OrderStatus.pending => tr('seller_orders.order_status_pending'),
    OrderStatus.confirmed => tr('seller_orders.order_status_confirmed'),
    OrderStatus.preparing => tr('seller_orders.action_preparing'),
    OrderStatus.shipped => tr('seller_orders.order_status_shipped'),
    OrderStatus.delivered => tr('seller_orders.action_delivered'),
    OrderStatus.cancelled => tr('seller_orders.tab_cancelled'),
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
        border: Border.all(color: c.primary.withValues(alpha: 0.08)),
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
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: c.onPrimarySoft,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('dashboard.empty_orders_title'),
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
            tr('dashboard.empty_orders_body'),
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
