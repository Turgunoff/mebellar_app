import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../config/app_mode.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../customer/features/notifications/cubit/notifications_cubit.dart';
import '../../../shared/models/notification_model.dart';
import '../notifications/screens/notifications_screen.dart';
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
// Screen — fully populated mock dashboard for an "active" seller.
// =============================================================================
class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key, this.onSeeAllOrders});

  /// Hook used by the home shell to switch to the orders tab when the user
  /// taps "Barchasi" on the recent-orders header.
  final VoidCallback? onSeeAllOrders;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _DashboardHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  const _Greeting(shopName: 'Archa Design'),
                  const SizedBox(height: 20),
                  const _KpiGrid(),
                  const SizedBox(height: 28),
                  _RecentOrdersHeader(onSeeAll: onSeeAllOrders),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _kMockOrders.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _RecentOrderTile(order: _kMockOrders[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 1. Header — "Boshqaruv" title + borderless Iconsax bell with Indigo badge
//
// Badge count and bell tap are wired to the root-scoped NotificationsCubit
// (registered in initRootScope). Filters to seller-target kinds locally so
// the customer side's broadcasts and order updates don't inflate the count.
// =============================================================================
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightBackground,
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: const [
          Expanded(
            child: Text(
              'Boshqaruv',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _ink,
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
          ),
          _NotificationBell(),
        ],
      ),
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
    // The cubit lives in root scope but isn't provided in seller's widget
    // tree (no MultiBlocProvider on SellerApp). Use the GetIt instance
    // directly via BlocProvider.value — BlocBuilder then subscribes to its
    // stream and rebuilds when the unread count changes.
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
// 2. Greeting — bold Jakarta with grey subtitle
// =============================================================================
class _Greeting extends StatelessWidget {
  const _Greeting({required this.shopName});

  final String shopName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Salom, $shopName!',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _ink,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Bugungi ko'rsatkichlaringiz",
          style: TextStyle(
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

// =============================================================================
// 3. KPI grid — 2×2 of `SellerKpiCard`s populated with active-shop mock data
// =============================================================================
class _KpiGrid extends StatelessWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // 1.15 was tight enough that the "Mahsulotlar" card — the only one
      // with a subtitle (tariff plan) under the value — overflowed by ~3px
      // on standard-width phones. Dropping to 1.05 buys roughly 7px of
      // vertical headroom, which fits the subtitle without making the
      // subtitle-less cards look obviously empty.
      childAspectRatio: 1.05,
      children: [
        const SellerKpiCard(
          icon: Iconsax.wallet_2,
          title: 'Bugungi savdo',
          value: '35 670 000',
          unit: 'UZS',
          accentValue: true,
          important: true,
        ),
        const SellerKpiCard(
          icon: Iconsax.shopping_bag,
          title: 'Bugungi orderlar',
          value: '14',
        ),
        const SellerKpiCard(
          icon: Iconsax.clock,
          title: 'Kutayotgan',
          value: '5',
        ),
        SellerKpiCard(
          icon: Iconsax.box,
          title: 'Mahsulotlar',
          value: '45 / 30',
          subtitle: 'Standard tarif',
          indicator: KpiIndicator.terracotta('Limit oshdi'),
        ),
      ],
    );
  }
}

// =============================================================================
// 4. Recent orders — section header + list of order cards
// =============================================================================
class _RecentOrdersHeader extends StatelessWidget {
  const _RecentOrdersHeader({required this.onSeeAll});

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
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
        TextButton(
          onPressed: onSeeAll ?? () {},
          style: TextButton.styleFrom(
            foregroundColor: AppColors.sellerPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Barchasi',
                style: TextStyle(fontFamily: AppFonts.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sellerPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Iconsax.arrow_right_3,
                size: 16,
                color: AppColors.sellerPrimary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({required this.order});

  final _MockOrder order;

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
                  order.number,
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
                  order.dateLabel,
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
                order.priceLabel,
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

// =============================================================================
// 5. Status pill — vibrant tint + saturated foreground
// =============================================================================
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _MockStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: status.fg,
          height: 1.0,
        ),
      ),
    );
  }
}

// =============================================================================
// Mock data
// =============================================================================
@immutable
class _MockStatus {
  const _MockStatus._({
    required this.label,
    required this.fg,
    required this.tint,
  });

  final String label;
  final Color fg;
  final Color tint;

  // Vibrant tint + saturated foreground keeps each pill legible at small
  // sizes. Don't darken `fg` without re-checking contrast against `tint`.
  static const delivered = _MockStatus._(
    label: 'Yetkazildi',
    fg: Color(0xFF1F6B49),
    tint: Color(0xFFDCF1E5),
  );
  static const inTransit = _MockStatus._(
    label: "Yo'lda",
    fg: Color(0xFF5B21B6),
    tint: Color(0xFFEDE3FF),
  );
  static const cancelled = _MockStatus._(
    label: 'Bekor qilingan',
    fg: Color(0xFFC0392B),
    tint: Color(0xFFFDECEA),
  );
  static const pending = _MockStatus._(
    label: 'Kutilmoqda',
    fg: Color(0xFF8C5A12),
    tint: Color(0xFFFFF1D6),
  );
}

@immutable
class _MockOrder {
  const _MockOrder({
    required this.number,
    required this.dateLabel,
    required this.priceLabel,
    required this.status,
  });

  final String number;
  final String dateLabel;
  final String priceLabel;
  final _MockStatus status;
}

const _kMockOrders = <_MockOrder>[
  _MockOrder(
    number: '#M-2026-FAKE-415',
    dateLabel: '05 may • 10:15',
    priceLabel: '4 150 000',
    status: _MockStatus.pending,
  ),
  _MockOrder(
    number: '#M-2026-FAKE-414',
    dateLabel: '05 may • 09:42',
    priceLabel: '12 800 000',
    status: _MockStatus.inTransit,
  ),
  _MockOrder(
    number: '#M-2026-FAKE-412',
    dateLabel: '04 may • 18:07',
    priceLabel: '2 690 000',
    status: _MockStatus.delivered,
  ),
  _MockOrder(
    number: '#M-2026-FAKE-409',
    dateLabel: '04 may • 14:33',
    priceLabel: '780 000',
    status: _MockStatus.cancelled,
  ),
];
