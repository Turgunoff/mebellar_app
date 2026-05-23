import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/models/analytics.dart';
import '../../../../shared/repositories/seller_analytics_repository.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/error_state.dart';
import '../bloc/seller_analytics_cubit.dart';
import '../widgets/analytics_common.dart';
import '../widgets/customers_tab.dart';
import '../widgets/orders_tab.dart';
import '../widgets/reviews_tab.dart';
import '../widgets/sales_tab.dart';

/// Premium seller analytics — four tabs (Sales / Orders / Reviews /
/// Customers) on top of a single repository snapshot. Filter row above
/// the tabs offers preset windows (7/30/90 kun, 12 oy) and a custom
/// date-range picker. Tab switches are pure view-model — no refetch.
class SellerAnalyticsScreen extends StatelessWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SellerAnalyticsCubit>(
      create: (_) => SellerAnalyticsCubit(sl<SellerAnalyticsRepository>())
        ..load(),
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<SellerAnalyticsCubit, SellerAnalyticsState>(
          builder: (context, state) {
            return Column(
              children: [
                const _AnalyticsHeader(),
                _RangeSelector(
                  filter: state.filter,
                  enabled: !state.isInitialLoad,
                  onChanged: (r) =>
                      context.read<SellerAnalyticsCubit>().changeRange(r),
                  onCustomPick: () => _pickCustomRange(context, state.filter),
                ),
                const SizedBox(height: 8),
                _TabBar(
                  active: state.tab,
                  enabled: !state.isInitialLoad,
                  onChanged: (tab) =>
                      context.read<SellerAnalyticsCubit>().changeTab(tab),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _AnalyticsBody(state: state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    AnalyticsFilter current,
  ) async {
    final now = DateTime.now();
    final earliest = DateTime(now.year - 3, 1, 1);
    final initial = (current.range == AnalyticsRange.custom &&
            current.customStart != null &&
            current.customEnd != null)
        ? DateTimeRange(start: current.customStart!, end: current.customEnd!)
        : DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: earliest,
      lastDate: now,
      initialDateRange: initial,
      saveText: 'Tanlash',
      cancelText: 'Bekor qilish',
      confirmText: 'OK',
      helpText: 'Sanani tanlang',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.terracotta,
              primary: AppColors.terracotta,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    if (!context.mounted) return;
    await context
        .read<SellerAnalyticsCubit>()
        .applyCustomRange(start: picked.start, end: picked.end);
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.state});

  final SellerAnalyticsState state;

  @override
  Widget build(BuildContext context) {
    if (state.isInitialLoad) {
      return const _SkeletonBody();
    }
    if (state.status == SellerAnalyticsStatus.failure &&
        state.snapshot == null) {
      return ErrorState(
        message: state.error,
        onRetry: () => context.read<SellerAnalyticsCubit>().load(),
      );
    }

    final snapshot = state.effectiveSnapshot;
    final refreshing = state.isReloading;
    return BrandRefreshIndicator(
      color: AppColors.sellerPrimary,
      onRefresh: () => context.read<SellerAnalyticsCubit>().refresh(),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previous,
            ?current,
          ],
        ),
        child: KeyedSubtree(
          key: ValueKey(state.tab),
          child: switch (state.tab) {
            AnalyticsTab.sales =>
              SalesTab(snapshot: snapshot, refreshing: refreshing),
            AnalyticsTab.orders =>
              OrdersTab(snapshot: snapshot, refreshing: refreshing),
            AnalyticsTab.reviews =>
              ReviewsTab(snapshot: snapshot, refreshing: refreshing),
            AnalyticsTab.customers =>
              CustomersTab(snapshot: snapshot, refreshing: refreshing),
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Header
// =============================================================================
class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightBackground,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Analitika',
              style: TextStyle(
                fontFamily: AppFonts.seller,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AnalyticsTokens.ink,
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
// Range selector — pill-shaped segmented control + custom date picker
// =============================================================================
class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.filter,
    required this.onChanged,
    required this.onCustomPick,
    this.enabled = true,
  });

  final AnalyticsFilter filter;
  final ValueChanged<AnalyticsRange> onChanged;
  final VoidCallback onCustomPick;
  final bool enabled;

  static const _labels = <AnalyticsRange, String>{
    AnalyticsRange.today: 'Bugun',
    AnalyticsRange.d7: '7 kun',
    AnalyticsRange.d30: '30 kun',
    AnalyticsRange.d90: '90 kun',
    AnalyticsRange.m12: '12 oy',
  };

  @override
  Widget build(BuildContext context) {
    final selected = filter.range;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _labels.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final r = _labels.keys.elementAt(i);
                  return _RangeSegment(
                    label: _labels[r]!,
                    active: r == selected,
                    onTap: enabled ? () => onChanged(r) : null,
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: _CustomRangeButton(
              active: selected == AnalyticsRange.custom,
              enabled: enabled,
              onTap: onCustomPick,
              label: _customLabel(filter),
            ),
          ),
        ],
      ),
    );
  }

  String _customLabel(AnalyticsFilter filter) {
    if (filter.range != AnalyticsRange.custom ||
        filter.customStart == null ||
        filter.customEnd == null) {
      return 'Sanani tanlash';
    }
    final s = filter.customStart!;
    final e = filter.customEnd!;
    return '${AnalyticsFmt.shortDate(s)} — ${AnalyticsFmt.shortDate(e)}';
  }
}

class _RangeSegment extends StatelessWidget {
  const _RangeSegment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.terracotta : AnalyticsTokens.segmentBg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.terracotta.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.seller,
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : AnalyticsTokens.grey,
            letterSpacing: -0.1,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _CustomRangeButton extends StatelessWidget {
  const _CustomRangeButton({
    required this.active,
    required this.enabled,
    required this.onTap,
    required this.label,
  });

  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.terracotta : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.terracotta : const Color(0xFFE5E5E5),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.terracotta.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.calendar_1,
              size: 16,
              color: active ? Colors.white : AnalyticsTokens.grey,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.seller,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AnalyticsTokens.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Tab bar (Sales / Orders / Reviews / Customers)
// =============================================================================
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.active,
    required this.onChanged,
    this.enabled = true,
  });

  final AnalyticsTab active;
  final ValueChanged<AnalyticsTab> onChanged;
  final bool enabled;

  static const _labels = ['Sotuvlar', 'Buyurtmalar', 'Baholar', 'Mijozlar'];
  static const _icons = [
    Iconsax.trend_up,
    Iconsax.shopping_bag,
    Iconsax.star_1,
    Iconsax.profile_2user,
  ];

  @override
  Widget build(BuildContext context) {
    return AnalyticsTabBar(
      activeIndex: AnalyticsTab.values.indexOf(active),
      labels: _labels,
      icons: _icons,
      onChanged: (i) {
        if (!enabled) return;
        onChanged(AnalyticsTab.values[i]);
      },
    );
  }
}

// =============================================================================
// Skeleton — shown on the very first load (no prior snapshot to lay over).
// =============================================================================
class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SkeletonCard(height: 220),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: _SkeletonCard(height: 96)),
            SizedBox(width: 10),
            Expanded(child: _SkeletonCard(height: 96)),
            SizedBox(width: 10),
            Expanded(child: _SkeletonCard(height: 96)),
          ],
        ),
        const SizedBox(height: 24),
        _SkeletonCard(height: 170),
        const SizedBox(height: 24),
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _SkeletonCard(height: 76),
        ],
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }
}
