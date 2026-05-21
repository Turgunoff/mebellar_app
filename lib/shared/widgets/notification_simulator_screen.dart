import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../config/app_mode.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../core/deep_links/deep_link_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/notifications/notification_handler.dart';
import '../models/app_notification.dart';
import '../repositories/notifications_repository.dart';

/// Debug-only screen that lets the developer fire any of the 6 cross-mode
/// notification scenarios from `docs/05-notifications-deep-linking.md` В§4.
/// Each tile crafts a notification + simulates the push lifecycle:
///   - "Foreground" tiles call `handleTap` directly with the active context
///   - "Background" tiles save the pending route only вЂ” the next consume
///     pass will pick it up
///   - "Cold start" tiles wipe the active mode setting first to mimic a
///     fresh app launch
class NotificationSimulatorScreen extends StatelessWidget {
  const NotificationSimulatorScreen({super.key, required this.currentMode});

  final AppMode currentMode;

  @override
  Widget build(BuildContext context) {
    final scenarios = _scenarios(currentMode);
    return Scaffold(
      appBar: AppBar(title: Text(tr('notifications.simulator_title'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('notifications.simulator_hint',
                          args: [tr('mode.${currentMode.name}')]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final scenario in scenarios)
            _ScenarioTile(scenario: scenario, currentMode: currentMode),
          const SizedBox(height: 24),
          const _ConnectivityToggleCard(),
          const SizedBox(height: 12),
          const _DeepLinkTesterCard(),
        ],
      ),
    );
  }

  List<_Scenario> _scenarios(AppMode current) {
    return [
      _Scenario(
        title: tr('notifications.scenario.same_foreground'),
        body: tr('notifications.scenario.same_foreground_hint'),
        action: _SimAction.tapForeground,
        notification: current == AppMode.customer
            ? _orderDeliveredTemplate()
            : _newOrderTemplate(),
      ),
      _Scenario(
        title: tr('notifications.scenario.cross_foreground'),
        body: tr('notifications.scenario.cross_foreground_hint'),
        action: _SimAction.tapForeground,
        notification: current == AppMode.customer
            ? _newOrderTemplate()
            : _orderDeliveredTemplate(),
      ),
      _Scenario(
        title: tr('notifications.scenario.same_background'),
        body: tr('notifications.scenario.same_background_hint'),
        action: _SimAction.stashOnly,
        notification: current == AppMode.customer
            ? _orderDeliveredTemplate()
            : _newOrderTemplate(),
      ),
      _Scenario(
        title: tr('notifications.scenario.cross_background'),
        body: tr('notifications.scenario.cross_background_hint'),
        action: _SimAction.stashOnly,
        notification: current == AppMode.customer
            ? _newOrderTemplate()
            : _orderDeliveredTemplate(),
      ),
      _Scenario(
        title: tr('notifications.scenario.same_cold'),
        body: tr('notifications.scenario.same_cold_hint'),
        action: _SimAction.coldStart,
        notification: current == AppMode.customer
            ? _orderDeliveredTemplate()
            : _newOrderTemplate(),
      ),
      _Scenario(
        title: tr('notifications.scenario.cross_cold'),
        body: tr('notifications.scenario.cross_cold_hint'),
        action: _SimAction.coldStart,
        notification: current == AppMode.customer
            ? _newOrderTemplate()
            : _orderDeliveredTemplate(),
      ),
    ];
  }
}

enum _SimAction { tapForeground, stashOnly, coldStart }

class _Scenario {
  const _Scenario({
    required this.title,
    required this.body,
    required this.action,
    required this.notification,
  });
  final String title;
  final String body;
  final _SimAction action;
  final AppNotification notification;
}

class _ScenarioTile extends StatelessWidget {
  const _ScenarioTile({required this.scenario, required this.currentMode});
  final _Scenario scenario;
  final AppMode currentMode;

  Future<void> _trigger(BuildContext context) async {
    final repo = sl<NotificationsRepository>();
    final handler = sl<NotificationHandler>();
    final messenger = ScaffoldMessenger.of(context);
    final notification = scenario.notification;

    // Always inject into the in-app inbox so the unread badge ticks up,
    // mirroring the OneSignal foreground listener behaviour.
    await repo.simulateIncoming(notification);

    switch (scenario.action) {
      case _SimAction.tapForeground:
        if (!context.mounted) return;
        await handler.handleTap(notification,
            currentMode: currentMode, context: context);
        if (notification.kind.mode == currentMode.name && context.mounted) {
          messenger.showSnackBar(SnackBar(
            content:
                Text(tr('notifications.simulator_done_same_mode')),
          ));
        }
      case _SimAction.stashOnly:
        handler.savePendingRoute(
          notification.route,
          notification.kind.mode,
          kind: notification.kind.code,
        );
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(tr('notifications.simulator_done_stash')),
          ));
        }
      case _SimAction.coldStart:
        handler.savePendingRoute(
          notification.route,
          notification.kind.mode,
          kind: notification.kind.code,
        );
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(tr('notifications.simulator_done_cold')),
          ));
        }
        // Switch app mode to mirror what would happen on cold start when
        // the saved app_mode differs from the payload's target mode.
        final targetMode = AppMode.fromName(notification.kind.mode);
        if (targetMode != currentMode && context.mounted) {
          await switchAppMode(context, targetMode);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(
          switch (scenario.action) {
            _SimAction.tapForeground => Icons.touch_app_outlined,
            _SimAction.stashOnly => Icons.cloud_download_outlined,
            _SimAction.coldStart => Icons.power_settings_new,
          },
          color: scheme.primary,
        ),
        title: Text(scenario.title),
        subtitle: Text(scenario.body),
        trailing: const Icon(Icons.play_arrow),
        onTap: () => _trigger(context),
      ),
    );
  }
}

/// Sprint 11 polish: flip the connectivity service so the offline banner +
/// any offline-first cache fallback in repositories can be exercised
/// without taking the device offline.
class _ConnectivityToggleCard extends StatelessWidget {
  const _ConnectivityToggleCard();

  @override
  Widget build(BuildContext context) {
    if (!sl.isRegistered<ConnectivityService>()) return const SizedBox.shrink();
    final service = sl<ConnectivityService>();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: StreamBuilder<ConnectivityStatus>(
        stream: service.watch(),
        initialData: service.status,
        builder: (context, snap) {
          final online = snap.data == ConnectivityStatus.online;
          return SwitchListTile(
            secondary: Icon(
              online ? Icons.wifi : Icons.wifi_off,
              color: online ? scheme.primary : scheme.error,
            ),
            value: online,
            onChanged: (next) => service.overrideStatus(
              next
                  ? ConnectivityStatus.online
                  : ConnectivityStatus.offline,
            ),
            title: Text(tr('offline.toggle_title')),
            subtitle: Text(online
                ? tr('offline.toggle_online')
                : tr('offline.toggle_offline')),
          );
        },
      ),
    );
  }
}

/// Sprint 11: paste any `mebellar://` or `https://mebellar.uz/...` URI to
/// fire `DeepLinkService.handleUri`. Useful for verifying the routing
/// rules without configuring the OS-level App Links handler.
class _DeepLinkTesterCard extends StatefulWidget {
  const _DeepLinkTesterCard();

  @override
  State<_DeepLinkTesterCard> createState() => _DeepLinkTesterCardState();
}

class _DeepLinkTesterCardState extends State<_DeepLinkTesterCard> {
  late final TextEditingController _ctrl =
      TextEditingController(text: 'mebellar://orders/ord-1001');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _fire() {
    if (!sl.isRegistered<DeepLinkService>()) return;
    sl<DeepLinkService>().handleUri(_ctrl.text.trim());
    final parsed = MockDeepLinkService.parse(_ctrl.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(parsed == null
          ? tr('deep_links.unrecognised')
          : tr('deep_links.routed', args: [parsed.mode.name, parsed.route])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  tr('deep_links.tester_title'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'mebellar://orders/ord-1001',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_outlined),
                  onPressed: _fire,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('deep_links.tester_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// File-local notification templates used by the cross-mode scenario tiles.
// Previously sourced from the shared mock fixtures; inlined here so the dev
// simulator stays self-contained and the fixtures package can live under
// `test/`.
AppNotification _newOrderTemplate() => AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      kind: NotificationKind.orderPlaced,
      title: 'Yangi buyurtma',
      body: 'Sizning do\'koningizga yangi buyurtma keldi',
      route: '/orders/ord-1001',
      createdAt: DateTime.now(),
    );

AppNotification _orderDeliveredTemplate() => AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      kind: NotificationKind.orderUpdated,
      title: 'Buyurtma yetkazildi',
      body: 'M-2026-002 raqamli buyurtma manzilingizga yetkazib berildi',
      route: '/orders/ord-1002',
      createdAt: DateTime.now(),
    );
