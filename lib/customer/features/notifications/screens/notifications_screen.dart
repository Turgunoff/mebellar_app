import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../config/app_mode.dart';
import '../../../../auth/auth_bottom_sheet.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/app_mode_cubit.dart';
import '../../../../core/auth/auth_cubit.dart';
import '../../../../core/deep_links/deep_link_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/widgets/brand_refresh_indicator.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../router.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../cubit/notifications_cubit.dart';

/// The three inbox tabs. `category == null` is the "Barchasi" (all) tab — no
/// filter; the other two filter the loaded inbox by
/// [NotificationModel.category]. Mirrors the `OrdersTab`/`tr('...tab_$name')`
/// convention so the labels live in the i18n bundles.
enum _NotificationsTab {
  all(null, 'tab_all'),
  orders(NotificationCategory.order, 'tab_orders'),
  system(NotificationCategory.system, 'tab_system');

  const _NotificationsTab(this.category, this.i18nKey);

  final NotificationCategory? category;
  final String i18nKey;
}

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
    final analytics = sl.isRegistered<AnalyticsService>()
        ? sl<AnalyticsService>()
        : null;
    unawaited(
      analytics?.notificationOpened(
        kind: notification.kind.code,
        opened: route != null,
      ),
    );

    // Trial-bonus grants are informational: in customer mode the tap only
    // toggles the tile open/closed in place — it must never reach GoRouter or
    // trigger a mode switch, even if a future payload starts carrying a route.
    // Belt-and-braces over determineRouteFor() already returning null here.
    if (notification.kind == NotificationKind.tariffBonusGranted &&
        context.read<AppModeCubit>().state == AppMode.customer) {
      return;
    }
    if (route == null) return;

    // A seller verdict invalidates the cached /me seller status behind the
    // profile banner ("Ko'rib chiqilmoqda" → "Tasdiqlandi"). Refetch BEFORE
    // navigating so the profile the user lands on already shows the verdict
    // — the profile tab lives in an IndexedStack, so nothing else would
    // refresh it without a manual pull. fetch() catches its own errors.
    if (notification.kind.isSellerVerdict && sl.isRegistered<ProfileCubit>()) {
      unawaited(sl<ProfileCubit>().fetch());
    }

    // Prefer the recipient mode carried in the payload (authoritative for
    // bi-directional kinds like chat) over the static per-kind mapping.
    final targetMode = notification.resolveTargetMode();
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

    // Tab destinations (/profile) switch the shell tab instead of pushing a
    // standalone screen — the user lands on the real bottom-nav tab.
    navigateCustomerRoute(GoRouter.of(context), route);
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

    return switch (n.kind) {
      // ---- Customer ------------------------------------------------------
      NotificationKind.order ||
      NotificationKind.orderCreated ||
      NotificationKind.orderShipped ||
      NotificationKind.orderDelivered =>
        orderId != null && orderId.isNotEmpty ? '/orders/$orderId' : '/orders',
      NotificationKind.priceDrop =>
        productId != null && productId.isNotEmpty
            ? '/product-detail/$productId'
            : '/',
      NotificationKind.supportReply => '/profile',

      // ---- Seller --------------------------------------------------------
      // Verification verdicts open the CUSTOMER profile in every case —
      // approved shows the "open seller panel" banner, rejected shows the
      // reason + resubmit banner. Never the seller shell (a rejected
      // applicant must not be mode-switched into it).
      NotificationKind.sellerApproved ||
      NotificationKind.sellerRejected => '/profile',
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

      // ---- Tariff lifecycle ------------------------------------------------
      // The bonus grant is purely informational — tapping expands the card
      // in place (see _NotificationTile.expandsOnTap) instead of bouncing
      // into seller mode. The expiry kinds DO navigate: the user has to act
      // (pick a plan / renew) on the tariff screen.
      NotificationKind.tariffBonusGranted => null,
      NotificationKind.tariffExpiring ||
      NotificationKind.tariffExpired => '/seller/tariff',

      // ---- Fee adjustment ------------------------------------------------
      // Customer receives 'proposed' → navigates to /orders/{id} to approve.
      // Seller receives 'response' → navigates to /seller/orders/{id}.
      NotificationKind.feeAdjustmentProposed =>
        orderId != null && orderId.isNotEmpty ? '/orders/$orderId' : '/orders',
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
      NotificationKind.promo =>
        _firstPayloadString(n, const [
              'promo_id',
              'campaign_id',
            ], prefix: '/promo/') ??
            '/promo',
      NotificationKind.news =>
        _firstPayloadString(n, const [
              'news_id',
              'article_id',
            ], prefix: '/news/') ??
            '/news',
      NotificationKind.systemAlert => '/system-alert',

      // ---- Chat ----------------------------------------------------------
      // Per-order chat thread. reference_id is the chat id; the payload's
      // `mode` decides which shell's route to build (customer vs seller).
      NotificationKind.chatMessage => _chatRoute(n),

      // ---- Informational — read-only, no destination ---------------------
      NotificationKind.review || NotificationKind.general => null,
    };
  }

  /// Resolves a chat notification to the right per-mode thread route. Falls
  /// back to the chat list when the chat id is missing.
  static String _chatRoute(NotificationModel n) {
    final chatId = n.referenceId ?? (n.payload?['chat_id'] as String?);
    final sellerSide = n.payload?['mode'] == AppMode.seller.name;
    if (chatId == null || chatId.isEmpty) {
      return sellerSide ? '/seller/chats' : '/chats';
    }
    return sellerSide ? '/seller/chats/$chatId' : '/chats/$chatId';
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
    return DefaultTabController(
      length: _NotificationsTab.values.length,
      child: Scaffold(
        backgroundColor: pt.background,
        appBar: AppBar(
          backgroundColor: pt.background,
          foregroundColor: pt.dark,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Iconsax.arrow_left_2_copy, size: 20, color: pt.dark),
            onPressed: () => context.pop(),
          ),
          title: Text(
            tr('notifications.title'),
            style: PremiumTokens.display(size: 22, letterSpacing: -0.4),
          ),
          actions: [
            // Marks the customer surface read (every tab), not just the
            // visible one — matches the bell, which counts customer unread.
            // Seller-panel rows are untouched (cleared from the seller inbox).
            BlocBuilder<NotificationsCubit, NotificationsState>(
              buildWhen: (a, b) =>
                  a.customerUnreadCount != b.customerUnreadCount,
              builder: (context, state) {
                if (state.customerUnreadCount == 0) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  color: PremiumTokens.accent,
                  tooltip: tr('notifications.mark_all_read'),
                  onPressed: () =>
                      context.read<NotificationsCubit>().markAllRead(),
                );
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: pt.dark,
            unselectedLabelColor: pt.grey,
            indicatorColor: PremiumTokens.accent,
            tabs: [
              for (final t in _NotificationsTab.values)
                Tab(text: tr('notifications.${t.i18nKey}')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final t in _NotificationsTab.values)
              _NotificationsList(
                category: t.category,
                onTap: (n) => _handleTap(context, n),
                // Routeless (informational) kinds expand in place so the full
                // text is readable without leaving the inbox.
                expandsOnTap: (n) => determineRouteFor(n) == null,
              ),
          ],
        ),
      ),
    );
  }
}

/// One tab's list: filters the loaded inbox by [category] (`null` = all) and
/// renders the shared loading / error / empty / list states. The cubit holds
/// the full inbox; tabs are a pure client-side filter over `state.items`, so
/// switching tabs never refetches.
class _NotificationsList extends StatelessWidget {
  const _NotificationsList({
    required this.category,
    required this.onTap,
    required this.expandsOnTap,
  });

  final NotificationCategory? category;
  final void Function(NotificationModel) onTap;
  final bool Function(NotificationModel) expandsOnTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        return switch (state.status) {
          NotificationsStatus.initial ||
          NotificationsStatus.loading => const _NotificationsSkeleton(),
          NotificationsStatus.failure when state.items.isEmpty => ErrorState(
            message: state.error,
            onRetry: () => context.read<NotificationsCubit>().load(),
          ),
          _ => _list(context, state),
        };
      },
    );
  }

  Widget _list(BuildContext context, NotificationsState state) {
    // Customer surface only — seller-panel alerts (new order, product approved,
    // …) are excluded here so the buyer's inbox never shows them. They live in
    // the seller mode inbox + the profile's "Sotuvchi paneliga o'tish" badge.
    final customerItems = state.customerItems;
    final guest = context.read<AuthCubit>().state is AppAuthUnauthenticated;

    // Personal (order) rows require a session. Guests still browse All /
    // System (public news + broadcasts); only this tab asks them to sign in.
    if (guest && category == NotificationCategory.order) {
      return EmptyState(
        icon: Iconsax.box_1,
        title: tr('notifications.orders_login_title'),
        message: tr('notifications.orders_login_message'),
        actionLabel: tr('notifications.login_cta'),
        action: () => showAuthScreen(context),
      );
    }

    // Inbox totally empty → first-run empty state (guests included — they may
    // simply have no public news yet; never block the whole screen on login).
    if (customerItems.isEmpty) {
      return EmptyState(
        icon: Iconsax.notification,
        title: tr('notifications.empty'),
        message: tr('notifications.empty_hint'),
      );
    }
    final items = category == null
        ? customerItems
        : customerItems
              .where((n) => n.category == category)
              .toList(growable: false);
    // Inbox has rows but none in this tab → a lighter "nothing here" empty.
    if (items.isEmpty) {
      return EmptyState(
        icon: Iconsax.notification,
        title: tr('notifications.empty'),
        message: tr('notifications.tab_empty'),
      );
    }
    return BrandRefreshIndicator(
      color: PremiumTokens.accent,
      onRefresh: () => context.read<NotificationsCubit>().load(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _NotificationTile(
          notification: items[i],
          expandsOnTap: expandsOnTap(items[i]),
          onTap: () => onTap(items[i]),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    this.expandsOnTap = false,
  });

  final NotificationModel notification;
  final VoidCallback onTap;

  /// Informational kinds (no destination route) toggle the clamped
  /// title/body open on tap so long copy — e.g. the trial-bonus grant —
  /// is readable without leaving the inbox.
  final bool expandsOnTap;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _expanded = false;

  bool _hasViewCta(NotificationKind kind) {
    return kind == NotificationKind.sellerApproved ||
        kind == NotificationKind.sellerRejected ||
        kind == NotificationKind.feeAdjustmentProposed ||
        kind == NotificationKind.feeAdjustmentResponse;
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final pt = PremiumTokens.of(context);
    final lang = context.locale.languageCode;
    final formatted = DateFormat(
      'dd MMM, HH:mm',
      lang,
    ).format(notification.createdAt.toLocal());
    final isRead = notification.isRead;
    final kindAccent = notification.kind.accent;
    // Unread rows get a faint tinted background + bolder title, so the
    // inbox immediately surfaces what the user hasn't seen yet. The tint
    // is the kind's accent at very low alpha so order/promo/news are also
    // visually distinguishable at a glance.
    final unreadTint = kindAccent.withValues(alpha: 0.05);
    return GestureDetector(
      onTap: () {
        if (widget.expandsOnTap) setState(() => _expanded = !_expanded);
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
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
                            maxLines: _expanded ? null : 1,
                            overflow: _expanded ? null : TextOverflow.ellipsis,
                            style: PremiumTokens.body(
                              size: 14,
                              weight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
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
                      _NotificationBody(
                        text: notification.body,
                        expanded: _expanded,
                        // Long informational copy (e.g. the trial-bonus grant)
                        // gets an explicit "read more / less" affordance so the
                        // full text is readable without leaving the inbox.
                        showToggle: widget.expandsOnTap,
                        accent: kindAccent,
                        onToggle: () => setState(() => _expanded = !_expanded),
                      ),
                    ],
                    if (_hasViewCta(notification.kind)) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            tr('notifications.view_cta'),
                            style: PremiumTokens.body(
                              size: 12,
                              weight: FontWeight.w700,
                              color: kindAccent,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Iconsax.arrow_right_3_copy,
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
      ),
    );
  }
}

/// Notification body text with an explicit, always-visible expand/collapse
/// toggle. The "read more" / "read less" row only appears when [showToggle] is
/// set (informational kinds) AND the copy would actually clamp at
/// [_collapsedLines] — so short notifications stay clean while long ones get an
/// obvious chevron. Measured per-build with a [TextPainter] against the real
/// available width, mirroring the seller `DescriptionCard` pattern.
class _NotificationBody extends StatelessWidget {
  const _NotificationBody({
    required this.text,
    required this.expanded,
    required this.showToggle,
    required this.accent,
    required this.onToggle,
  });

  static const _collapsedLines = 3;

  final String text;
  final bool expanded;
  final bool showToggle;
  final Color accent;
  final VoidCallback onToggle;

  bool _clamps(BuildContext context, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: _collapsedLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final style = PremiumTokens.body(size: 13, color: pt.grey, height: 1.35);
    return LayoutBuilder(
      builder: (context, constraints) {
        final clamps = _clamps(context, style, constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: expanded ? null : _collapsedLines,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: style,
            ),
            if (showToggle && clamps) ...[
              const SizedBox(height: 6),
              GestureDetector(
                // Nested inside the tile's GestureDetector — it wins the arena
                // for taps on the chevron, so this only flips expand/collapse
                // and never re-fires the tile's mark-read/route handler.
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(
                        expanded
                            ? 'notifications.read_less'
                            : 'notifications.read_more',
                      ),
                      style: PremiumTokens.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: accent,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                      size: 14,
                      color: accent,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
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
