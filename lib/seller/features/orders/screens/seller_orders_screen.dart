import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../bloc/seller_orders_bloc.dart';
import '../widgets/order_format.dart';
import 'order_details_screen.dart';

// Local tokens — kept here so this screen reads top-to-bottom without
// chasing theme indirection. Plus Jakarta Sans is applied to every `Text`
// explicitly per the design spec rather than inheriting from the seller
// theme; this protects the screen from theme regressions.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyMid = Color(0xFFBDBDBD);
const _divider = Color(0xFFEAEAEA);

/// Maps the 4 tab indices to the bloc's [SellerOrdersTab] enum.
const _tabsInOrder = <SellerOrdersTab>[
  SellerOrdersTab.newTab,
  SellerOrdersTab.active,
  SellerOrdersTab.done,
  SellerOrdersTab.cancelled,
];

// =============================================================================
// Screen — premium orders list backed by SellerOrdersBloc.
// =============================================================================
class SellerOrdersScreen extends StatelessWidget {
  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The bloc is a seller-scope singleton provided by SellerRouterShell so
    // the bottom-nav badge stays live across tab switches. BlocProvider.value
    // makes it reachable by child widgets without taking ownership.
    return BlocProvider<SellerOrdersBloc>.value(
      value: sl<SellerOrdersBloc>(),
      child: const _SellerOrdersView(),
    );
  }
}

class _SellerOrdersView extends StatefulWidget {
  const _SellerOrdersView();

  @override
  State<_SellerOrdersView> createState() => _SellerOrdersViewState();
}

class _SellerOrdersViewState extends State<_SellerOrdersView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabsInOrder.length, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Fires on both tap and swipe; mirror the active tab into the bloc so the
    // unread-"new" badge clears when the seller opens that tab.
    if (_tabs.indexIsChanging) return;
    context
        .read<SellerOrdersBloc>()
        .add(SellerOrdersTabChanged(_tabsInOrder[_tabs.index]));
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _OrdersHeader(),
            _OrdersTabBar(controller: _tabs),
            Expanded(
              child: BlocBuilder<SellerOrdersBloc, SellerOrdersState>(
                builder: (context, state) {
                  switch (state.status) {
                    case SellerOrdersStatus.initial:
                    case SellerOrdersStatus.loading:
                      return const Center(child: BrandLoadingIndicator());
                    case SellerOrdersStatus.failure:
                      return _OrdersError(
                        message: state.error ??
                            "Buyurtmalarni yuklab bo'lmadi",
                        onRetry: () => context
                            .read<SellerOrdersBloc>()
                            .add(const SellerOrdersRequested()),
                      );
                    case SellerOrdersStatus.ready:
                      return TabBarView(
                        controller: _tabs,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          for (final tab in _tabsInOrder)
                            _OrdersList(
                              orders: state.orders
                                  .where(tab.matches)
                                  .toList(growable: false),
                              emptyMessage: _emptyMessageFor(tab),
                              onRefresh: () async {
                                context
                                    .read<SellerOrdersBloc>()
                                    .add(const SellerOrdersRequested());
                                await context
                                    .read<SellerOrdersBloc>()
                                    .stream
                                    .firstWhere(
                                      (s) =>
                                          s.status !=
                                          SellerOrdersStatus.loading,
                                    );
                              },
                            ),
                        ],
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _emptyMessageFor(SellerOrdersTab tab) => switch (tab) {
        SellerOrdersTab.newTab => "Yangi buyurtmalar yo'q",
        SellerOrdersTab.active => "Faol buyurtmalar yo'q",
        SellerOrdersTab.done => "Yetkazilgan buyurtmalar yo'q",
        SellerOrdersTab.cancelled => "Bekor qilingan buyurtmalar yo'q",
      };
}

// =============================================================================
// Header
// =============================================================================
class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightBackground,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Buyurtmalar',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _ink,
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab bar — terracotta indicator, Jakarta labels
// =============================================================================
class _OrdersTabBar extends StatelessWidget {
  const _OrdersTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightBackground,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppColors.terracotta,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.terracotta,
        unselectedLabelColor: _grey,
        labelStyle: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
        dividerColor: _divider,
        dividerHeight: 1,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: const [
          Tab(text: 'Yangi'),
          Tab(text: 'Faol'),
          Tab(text: 'Yetkazilgan'),
          Tab(text: 'Bekor qilingan'),
        ],
      ),
    );
  }
}

// =============================================================================
// Per-tab list
// =============================================================================
class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.emptyMessage,
    required this.onRefresh,
  });

  final List<Order> orders;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: BrandRefreshIndicator(
        color: AppColors.sellerPrimary,
        onRefresh: onRefresh,
        child: orders.isEmpty
            // Empty state needs to be a scrollable so pull-to-refresh has
            // overscroll to react to — a static widget would swallow the
            // gesture and the indicator would never appear.
            ? ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: _EmptyTab(message: emptyMessage),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: orders.length,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.only(
                    bottom: i == orders.length - 1 ? 0 : 12,
                  ),
                  child: _OrderCard(order: orders[i]),
                ),
              ),
      ),
    );
  }
}

// =============================================================================
// Order card — tappable; opens the bloc-backed detail screen.
// =============================================================================
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final colors = sellerOrderStatusColors(order.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // The list route stays mounted beneath the pushed detail, so its
            // bloc is a valid `onUpdated` sink for the detail's transitions.
            final ordersBloc = context.read<SellerOrdersBloc>();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OrderDetailsScreen(
                  orderId: order.id,
                  ordersBloc: ordersBloc,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.orderNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.seller,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Iconsax.clock, size: 14, color: _grey),
                    const SizedBox(width: 4),
                    Text(
                      formatOrderDateTime(order.createdAt),
                      style: TextStyle(
                        fontFamily: AppFonts.seller,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _grey,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 1, color: _divider),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jami',
                            style: TextStyle(
                              fontFamily: AppFonts.seller,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _greyMid,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              text: formatOrderAmount(order.grandTotal),
                              style: TextStyle(
                                fontFamily: AppFonts.seller,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                              children: [
                                TextSpan(
                                  text: '  UZS',
                                  style: TextStyle(
                                    fontFamily: AppFonts.seller,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _greyMid,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(
                      label: sellerOrderStatusLabel(order.status),
                      bg: colors.bg,
                      fg: colors.fg,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.seller,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }
}

// =============================================================================
// Empty + error states
// =============================================================================
class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F1F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.shopping_bag,
                size: 28,
                color: _greyMid,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.warning_2, size: 40, color: _greyMid),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Qayta urinish',
                  style: TextStyle(
                    fontFamily: AppFonts.seller,
                    fontWeight: FontWeight.w600,
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
