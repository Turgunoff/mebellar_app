import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/app_mode.dart';
import '../../core/di/service_locator.dart';
import '../../core/notifications/notification_handler.dart';
import '../bloc/notifications_bloc.dart';
import '../models/app_notification.dart';
import '../repositories/notifications_repository.dart';
import 'empty_state.dart';
import 'error_state.dart';

/// Single screen used by both customer and seller modes вЂ” `mode` controls
/// the filter (only show notifications addressed to that mode) and which
/// "mark all read" scope is used.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotificationsBloc(sl<NotificationsRepository>())
        ..add(const NotificationsRequested()),
      child: _NotificationsView(mode: mode),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView({required this.mode});
  final AppMode mode;

  Future<void> _onTap(BuildContext context, AppNotification n) async {
    final bloc = context.read<NotificationsBloc>();
    bloc.add(NotificationRead(n.id));

    final handler = sl<NotificationHandler>();
    if (n.kind.mode == mode.name) {
      // Same-mode в†’ push directly via the active router.
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // The active router doesn't accept arbitrary route strings via
      // `pushNamed` for our go_router setup, so we stash and let the
      // mode shell `_consumePendingRoute` resolve it consistently.
      handler.savePendingRoute(n.route, n.kind.mode, kind: n.kind.code);
      // Force a rebuild of the shell by no-op switching to the same mode
      // is too heavy; instead the next frame the consume callback fires
      // because the user is already on the same mode and the shell rebuilt.
      // Sprint 11 polish swaps this for a direct GoRouter handle.
    } else {
      Navigator.of(context).pop();
      await handler.handleTap(n,
          currentMode: mode, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        final visible = state.items
            .where((n) => n.kind.mode == mode.name)
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('notifications.title')),
            actions: [
              if (visible.any((n) => !n.read))
                TextButton(
                  onPressed: () => context
                      .read<NotificationsBloc>()
                      .add(NotificationsAllRead(mode: mode.name)),
                  child: Text(tr('notifications.mark_all_read')),
                ),
            ],
          ),
          body: switch (state.status) {
            NotificationsStatus.initial ||
            NotificationsStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            NotificationsStatus.failure when state.items.isEmpty =>
              ErrorState(
                message: state.error,
                onRetry: () => context
                    .read<NotificationsBloc>()
                    .add(const NotificationsRequested()),
              ),
            _ => visible.isEmpty
                ? EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: tr('notifications.empty'),
                    message: tr('notifications.empty_hint'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _NotificationTile(
                      notification: visible[i],
                      onTap: () => _onTap(context, visible[i]),
                    ),
                  ),
          },
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd MMM, HH:mm', lang);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: notification.read
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
        child: Icon(
          notification.kind.icon,
          color: notification.read ? scheme.outline : scheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.read ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(notification.body),
          const SizedBox(height: 4),
          Text(
            dateFmt.format(notification.createdAt.toLocal()),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
          ),
        ],
      ),
      trailing: notification.read
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
      onTap: onTap,
    );
  }
}
