import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/models/notification_model.dart';
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
  /// Tap behaviour:
  ///   1. Optimistically flip `is_read` so the badge clears immediately.
  ///   2. If the notification carries a `reference_id` and the kind has a
  ///      known route (currently only `order`), push the destination.
  /// Other kinds (news / promo / review / general) just dismiss the unread
  /// state — they're informational and don't deep-link anywhere yet.
  void _handleTap(BuildContext context, NotificationModel notification) {
    context.read<NotificationsCubit>().markRead(notification.id);
    final ref = notification.referenceId;
    if (ref == null || ref.isEmpty) return;
    switch (notification.kind) {
      case NotificationKind.order:
        context.push('/orders/$ref');
      case NotificationKind.news:
      case NotificationKind.promo:
      case NotificationKind.review:
      case NotificationKind.general:
        // No destination wired yet — extend here when product / promo
        // detail screens land.
        break;
    }
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
                : RefreshIndicator(
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
