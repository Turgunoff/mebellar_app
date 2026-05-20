import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../config/app_mode.dart';
import '../../../../core/auth/app_mode_cubit.dart';
import '../../../../core/deep_links/deep_link_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../customer/features/notifications/cubit/notifications_cubit.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';

// Tones picked to match the seller dashboard surface — same `_ink` / `_grey`
// the dashboard uses, so the inbox feels like an extension of "Backoffice"
// rather than a separate screen. Indigo accents come from `AppColors`.
const _ink = Color(0xFF1D1D1D);
const _grey = Color(0xFF757575);
const _greyLight = Color(0xFFBDBDBD);
const _surfaceWhite = Colors.white;

/// Seller-mode inbox. Mirrors the customer screen's layout but renders with
/// the seller theme (Indigo accents, Plus Jakarta Sans inherited from the
/// theme, opaque white tiles like the dashboard cards).
///
/// Data source: the root-scoped [NotificationsCubit] (same instance the
/// customer screen consumes). Filtering by `kind.targetMode == seller`
/// hides customer-only kinds (news, promo, price drops, order status, ...)
/// from the seller view while keeping the unread badge math consistent
/// across both shells.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsCubit>.value(
      value: sl<NotificationsCubit>(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView();

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  /// Same routing interceptor as the customer screen — see
  /// `customer/features/notifications/screens/notifications_screen.dart` for
  /// the full doc. The difference here is the cross-mode direction: a
  /// `promo` or `news` tap from seller mode stashes the route then flips
  /// `AppModeCubit` to customer; Phoenix.rebirth lands the user on the
  /// customer router which consumes the pending route.
  void _handleTap(BuildContext context, NotificationModel notification) {
    context.read<NotificationsCubit>().markRead(notification.id);
    final route = determineRouteFor(notification);
    if (route == null) return;

    final targetMode = notification.kind.targetMode;
    final currentMode = context.read<AppModeCubit>().state;

    if (currentMode != targetMode) {
      sl<DeepLinkService>().setPendingRoute(route);
      context.read<AppModeCubit>().switchMode(targetMode);
      return;
    }

    // Same-mode push for seller routes (e.g. seller_new_order →
    // /seller/orders/:id). The seller MaterialApp doesn't ship a
    // GoRouter yet — `pushNamed` is a no-op when the route isn't mapped
    // in `onGenerateRoute`. The cubit's `markRead` still fires, so the
    // badge stays correct even if navigation can't complete.
    Navigator.of(context).pushNamed(route);
  }

  /// Mirrors the customer-side `determineRouteFor` (kept in sync by hand —
  /// when adding a kind, update both). Returns `null` for purely
  /// informational kinds so the caller only flips the read flag.
  static String? determineRouteFor(NotificationModel n) {
    final ref = n.referenceId;
    final orderId = ref ?? (n.payload?['order_id'] as String?);
    final productId = ref ?? (n.payload?['product_id'] as String?);
    final productSlug = n.payload?['product_slug'] as String?;

    return switch (n.kind) {
      // ---- Customer (cross-mode taps from seller) ------------------------
      NotificationKind.order ||
      NotificationKind.orderCreated ||
      NotificationKind.orderShipped ||
      NotificationKind.orderDelivered =>
        orderId != null && orderId.isNotEmpty
            ? '/orders/$orderId'
            : '/orders',
      NotificationKind.priceDrop => productSlug != null && productSlug.isNotEmpty
          ? '/products/$productSlug'
          : (productId != null && productId.isNotEmpty
              ? '/product-detail/$productId'
              : '/'),
      NotificationKind.supportReply => '/profile',

      // ---- Seller --------------------------------------------------------
      NotificationKind.sellerApproved ||
      NotificationKind.sellerRejected => '/seller/profile',
      NotificationKind.sellerNewOrder ||
      NotificationKind.sellerOrderCancelled =>
        orderId != null && orderId.isNotEmpty
            ? '/seller/orders/$orderId'
            : '/seller/orders',
      NotificationKind.sellerProductApproved ||
      NotificationKind.sellerProductRejected =>
        productId != null && productId.isNotEmpty
            ? '/seller/products/$productId'
            : '/seller/products',
      NotificationKind.sellerLowStock => '/seller/products',

      // ---- Broadcasts (also cross-mode from seller) ----------------------
      NotificationKind.promo => _payloadDeepLink(n, const ['promo_id', 'campaign_id'], '/promo/') ?? '/promo',
      NotificationKind.news => _payloadDeepLink(n, const ['news_id', 'article_id'], '/news/') ?? '/news',
      NotificationKind.systemAlert => '/system-alert',

      NotificationKind.review ||
      NotificationKind.general => null,
    };
  }

  static String? _payloadDeepLink(
    NotificationModel n,
    List<String> keys,
    String prefix,
  ) {
    final payload = n.payload;
    if (payload == null) return null;
    for (final key in keys) {
      final value = payload[key];
      if (value is String && value.isNotEmpty) return '$prefix$value';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        // titleSpacing 0 + the smaller font reclaim room for the long
        // "Hammasini o'qildi" action button. Without these tweaks the
        // Uzbek title "Bildirishnomalar" (15 chars) gets ellipsis'd to
        // "Bildirishnom..." next to the action.
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: _ink,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          tr('notifications.title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // fontFamily intentionally omitted — seller theme pins Plus
          // Jakarta Sans on every TextStyle, see seller_theme.dart.
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            buildWhen: (a, b) =>
                _unreadFor(a) != _unreadFor(b),
            builder: (context, state) {
              if (_unreadFor(state) == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () =>
                    context.read<NotificationsCubit>().markAllRead(),
                child: Text(
                  tr('notifications.mark_all_read'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sellerPrimary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          final items = _sellerItems(state.items);
          return switch (state.status) {
            NotificationsStatus.initial ||
            NotificationsStatus.loading => const _SellerNotificationsSkeleton(),
            NotificationsStatus.failure when items.isEmpty => ErrorState(
              message: state.error,
              onRetry: () => context.read<NotificationsCubit>().load(),
            ),
            _ => items.isEmpty
                ? EmptyState(
                    icon: Iconsax.notification,
                    title: tr('notifications.empty'),
                    message: tr('notifications.empty_hint'),
                  )
                : BrandRefreshIndicator(
                    color: AppColors.sellerPrimary,
                    onRefresh: () =>
                        context.read<NotificationsCubit>().load(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _NotificationTile(
                        notification: items[i],
                        onTap: () => _handleTap(context, items[i]),
                      ),
                    ),
                  ),
          };
        },
      ),
    );
  }

  /// Filters the cubit's unified inbox down to rows whose `targetMode` is
  /// seller. The customer screen does the symmetric filter — both screens
  /// share the same in-memory list and pick what to render locally.
  static List<NotificationModel> _sellerItems(List<NotificationModel> all) {
    return all
        .where((n) => n.kind.targetMode == AppMode.seller)
        .toList(growable: false);
  }

  static int _unreadFor(NotificationsState state) {
    return _sellerItems(state.items).where((n) => !n.isRead).length;
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final formatted = DateFormat('dd MMM, HH:mm', lang)
        .format(notification.createdAt.toLocal());
    final isRead = notification.isRead;
    final kindAccent = notification.kind.accent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // Seller surface aesthetic: pure white tiles with a soft drop
          // shadow, matching the dashboard's KPI cards and order rows.
          // Unread state is signalled by the indigo dot + left-edge stripe
          // rather than a tinted background — keeps the inbox calm.
          color: _surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: isRead
              ? null
              : Border(
                  left: BorderSide(
                    color: AppColors.sellerPrimary,
                    width: 3,
                  ),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isRead
                    ? const Color(0xFFF2F2F2)
                    : kindAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                notification.kind.icon,
                size: 18,
                color: isRead ? _grey : kindAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isRead ? FontWeight.w600 : FontWeight.w700,
                            color: _ink,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.sellerPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _grey,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    formatted,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _greyLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerNotificationsSkeleton extends StatelessWidget {
  const _SellerNotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: const Color(0xFFF2F2F2),
        highlightColor: _surfaceWhite,
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
