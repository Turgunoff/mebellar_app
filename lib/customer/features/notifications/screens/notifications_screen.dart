import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../config/app_mode.dart';
import '../../../../core/auth/app_mode_cubit.dart';
import '../../../../core/deep_links/deep_link_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/notifications_cubit.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuse the customer-scoped singleton so this screen and the home-shell
    // bell badge share state — marking a notification read here flips the
    // badge in the same frame (no second fetch).
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
  /// Tap behaviour — single routing interceptor that all kinds flow through:
  ///   1. Optimistically flip `is_read` so the badge clears immediately.
  ///   2. Resolve the destination route from the notification's kind and
  ///      payload (see [determineRouteFor]).
  ///   3. Compare `notification.kind.targetMode` to the active [AppMode]:
  ///        * Match → `context.push(route)` and we stay in this shell.
  ///        * Mismatch → stash the route in [DeepLinkService] and switch
  ///          modes via [AppModeCubit.switchMode]. The mode-swap listener
  ///          in `main.dart` will trigger `Phoenix.rebirth`; the target
  ///          shell's `initState` consumes the pending route and navigates.
  ///   4. `null` route → only the read-flag flip runs (informational kind).
  void _handleTap(BuildContext context, NotificationModel notification) {
    context.read<NotificationsCubit>().markRead(notification.id);
    final route = determineRouteFor(notification);
    if (route == null) return;

    final targetMode = notification.kind.targetMode;
    final currentMode = context.read<AppModeCubit>().state;

    if (currentMode != targetMode) {
      // Cross-mode: persist the destination *before* requesting the mode
      // swap. Phoenix.rebirth will replace this widget tree, so any state
      // we hold on the way out is lost — only the Hive-backed pending
      // route survives the rebirth and is consumed by the new shell's
      // `_consumePendingRoute` on the next frame.
      sl<DeepLinkService>().setPendingRoute(route);
      context.read<AppModeCubit>().switchMode(targetMode);
      return;
    }

    // Order detail routes need the orders list in the back stack so the user
    // can press back and land on the list (Shell → Orders → Order Detail).
    // We capture the router before calling go() because go() unmounts this
    // widget — context.mounted will be false in the post-frame callback.
    if (route.startsWith('/orders/')) {
      final router = GoRouter.of(context);
      router.go('/');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.push('/orders');
        router.push(route);
      });
      return;
    }

    context.push(route);
  }

  /// Resolves the deep-link destination for [n]. Returns `null` for purely
  /// informational kinds (news / promo / review / general) so the caller
  /// stops at the read-flag flip.
  ///
  /// Routes are deliberately literal here — once the seller GoRouter lands
  /// in a follow-up Sprint, the `/seller/...` paths will resolve directly
  /// against it; until then they're picked up by `Navigator.pushNamed` in
  /// the seller shell (currently a no-op for unmapped names, which is OK
  /// — the mode swap alone delivers the user to the right surface).
  static String? determineRouteFor(NotificationModel n) {
    final ref = n.referenceId;
    final orderId = ref ?? (n.payload?['order_id'] as String?);
    final productId = ref ?? (n.payload?['product_id'] as String?);
    final productSlug = n.payload?['product_slug'] as String?;

    return switch (n.kind) {
      // ---- Customer ------------------------------------------------------
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

      // ---- Fee adjustment ------------------------------------------------
      // Customer receives 'proposed' → navigates to /orders/{id} to approve.
      // Seller receives 'response' → navigates to /seller/orders/{id}.
      NotificationKind.feeAdjustmentProposed =>
        orderId != null && orderId.isNotEmpty
            ? '/orders/$orderId'
            : '/orders',
      NotificationKind.feeAdjustmentResponse =>
        orderId != null && orderId.isNotEmpty
            ? '/seller/orders/$orderId'
            : '/seller/orders',

      // ---- Global broadcasts ---------------------------------------------
      // Marketing/system kinds always target customer mode (see
      // `NotificationKindRouting.targetMode`). When a seller taps one, the
      // interceptor stashes the route here, flips mode, and the rebirthed
      // customer shell consumes it on first frame.
      //
      // The routes are deliberately literal placeholders for now — the
      // dedicated `/promo` and `/news` screens land in a follow-up. Until
      // then a missing route in GoRouter falls back to its error page;
      // wire those routes (or remap to `/` as a safe fallback) before
      // shipping these notification types to production users.
      NotificationKind.promo => _firstPayloadString(
            n,
            const ['promo_id', 'campaign_id'],
            prefix: '/promo/',
          ) ??
          '/promo',
      NotificationKind.news => _firstPayloadString(
            n,
            const ['news_id', 'article_id'],
            prefix: '/news/',
          ) ??
          '/news',
      NotificationKind.systemAlert => '/system-alert',

      // ---- Informational — read-only, no destination ---------------------
      NotificationKind.review ||
      NotificationKind.general => null,
    };
  }

  /// Returns the first non-empty payload value at any of [keys], wrapped in
  /// [prefix]. Lets a single promo notification land on `/promo/sale-2026`
  /// when the backend includes a `promo_id` and gracefully degrade to the
  /// generic `/promo` listing otherwise.
  static String? _firstPayloadString(
    NotificationModel n,
    List<String> keys, {
    required String prefix,
  }) {
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
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      appBar: AppBar(
        backgroundColor: pt.background,
        foregroundColor: pt.dark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: pt.dark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          tr('notifications.title'),
          style: PremiumTokens.display(size: 22, letterSpacing: -0.4),
        ),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            buildWhen: (a, b) => a.unreadCount != b.unreadCount,
            builder: (context, state) {
              if (state.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () =>
                    context.read<NotificationsCubit>().markAllRead(),
                child: Text(
                  tr('notifications.mark_all_read'),
                  style: PremiumTokens.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: PremiumTokens.accent,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          return switch (state.status) {
            NotificationsStatus.initial ||
            NotificationsStatus.loading => const _NotificationsSkeleton(),
            NotificationsStatus.failure when state.items.isEmpty => ErrorState(
              message: state.error,
              onRetry: () => context.read<NotificationsCubit>().load(),
            ),
            _ => state.items.isEmpty
                ? EmptyState(
                    icon: Iconsax.notification,
                    title: tr('notifications.empty'),
                    message: tr('notifications.empty_hint'),
                  )
                : BrandRefreshIndicator(
                    color: PremiumTokens.accent,
                    onRefresh: () =>
                        context.read<NotificationsCubit>().load(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: state.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _NotificationTile(
                        notification: state.items[i],
                        onTap: () => _handleTap(context, state.items[i]),
                      ),
                    ),
                  ),
          };
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  bool _hasViewCta(NotificationKind kind) {
    return kind == NotificationKind.sellerApproved ||
        kind == NotificationKind.sellerRejected ||
        kind == NotificationKind.feeAdjustmentProposed ||
        kind == NotificationKind.feeAdjustmentResponse;
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final lang = context.locale.languageCode;
    final formatted = DateFormat('dd MMM, HH:mm', lang)
        .format(notification.createdAt.toLocal());
    final isRead = notification.isRead;
    final kindAccent = notification.kind.accent;
    // Unread rows get a faint tinted background + bolder title, so the
    // inbox immediately surfaces what the user hasn't seen yet. The tint
    // is the kind's accent at very low alpha so order/promo/news are also
    // visually distinguishable at a glance.
    final unreadTint = kindAccent.withValues(alpha: 0.05);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: isRead ? pt.surface : unreadTint,
          borderRadius: BorderRadius.circular(18),
          boxShadow: PremiumTokens.softShadow,
          border: isRead
              ? null
              : Border.all(
                  color: kindAccent.withValues(alpha: 0.22),
                  width: 1,
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isRead
                    ? pt.imageBg
                    : kindAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                notification.kind.icon,
                size: 20,
                color: isRead ? pt.grey : kindAccent,
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
                          style: PremiumTokens.body(
                            size: 14,
                            weight: isRead ? FontWeight.w600 : FontWeight.w700,
                            color: pt.dark,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: PremiumTokens.accent,
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
                      style: PremiumTokens.body(
                        size: 13,
                        color: pt.grey,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (_hasViewCta(notification.kind)) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          "Ko'rish",
                          style: PremiumTokens.body(
                            size: 12,
                            weight: FontWeight.w700,
                            color: kindAccent,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Iconsax.arrow_right_3,
                          size: 14,
                          color: kindAccent,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    formatted,
                    style: PremiumTokens.body(
                      size: 11,
                      weight: FontWeight.w500,
                      color: pt.greyLight,
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

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: pt.imageBg,
        highlightColor: pt.surface,
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: pt.imageBg,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
