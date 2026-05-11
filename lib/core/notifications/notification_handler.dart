import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/app_mode.dart';
import '../../shared/models/app_notification.dart';
import '../../shared/repositories/notifications_repository.dart';
import '../di/service_locator.dart';

/// Cross-mode push handler. Sprint 1 scaffolded the pending-route box;
/// Sprint 10 fleshes it out with the full payload-routing rules from
/// `docs/05-notifications-deep-linking.md`:
///
/// 1. **Mode matches** → navigate immediately (caller passes [navigator]).
/// 2. **Mode differs** → save pending route + flip app mode; the target
///    app's `_consumePendingRoute()` picks it up on `initState`.
/// 3. **Stale** (>5 min) → drop.
class NotificationHandler {
  NotificationHandler(this._pendingRoute);

  final Box _pendingRoute;

  static const String _routeKey = 'pending_route';
  static const String _modeKey = 'pending_mode';
  static const String _tsKey = 'pending_ts';
  static const String _kindKey = 'pending_kind';
  static const Duration _staleAfter = Duration(minutes: 5);

  void savePendingRoute(String route, String mode, {String? kind}) {
    _pendingRoute.put(_routeKey, route);
    _pendingRoute.put(_modeKey, mode);
    _pendingRoute.put(_tsKey, DateTime.now().toIso8601String());
    if (kind != null) _pendingRoute.put(_kindKey, kind);
  }

  /// Returns the route to navigate to once, or `null` if there is none or it
  /// is stale. Always clears the saved value.
  String? consumeFor(String mode) {
    final route = _pendingRoute.get(_routeKey) as String?;
    final savedMode = _pendingRoute.get(_modeKey) as String?;
    final tsRaw = _pendingRoute.get(_tsKey) as String?;
    _pendingRoute.delete(_routeKey);
    _pendingRoute.delete(_modeKey);
    _pendingRoute.delete(_tsKey);
    _pendingRoute.delete(_kindKey);

    if (route == null || savedMode != mode || tsRaw == null) return null;
    final ts = DateTime.tryParse(tsRaw);
    if (ts == null || DateTime.now().difference(ts) > _staleAfter) {
      return null;
    }
    return route;
  }

  /// Inspects the pending payload without consuming it — used by cold-start
  /// boot to decide which initial app mode to render.
  ({String mode, String route})? peek() {
    final route = _pendingRoute.get(_routeKey) as String?;
    final mode = _pendingRoute.get(_modeKey) as String?;
    final tsRaw = _pendingRoute.get(_tsKey) as String?;
    if (route == null || mode == null || tsRaw == null) return null;
    final ts = DateTime.tryParse(tsRaw);
    if (ts == null || DateTime.now().difference(ts) > _staleAfter) return null;
    return (mode: mode, route: route);
  }

  /// Entry point invoked from a tap on a system tray push. The [currentMode]
  /// argument is the mode that the user is *currently* in; the payload may
  /// belong to a different mode in which case we stash the route and flip.
  ///
  /// `navigator` is optional — when provided and the modes match, the
  /// handler routes immediately. When omitted (e.g. cold start before the
  /// router exists), the route is always stashed and consumed on init.
  Future<void> handleTap(
    AppNotification notification, {
    required AppMode currentMode,
    BuildContext? context,
  }) async {
    final targetMode = AppMode.fromName(notification.kind.mode);
    // Always mirror the inbound notification into the in-app inbox so the
    // notifications list shows it even if the system tray was the only
    // touchpoint.
    if (sl.isRegistered<NotificationsRepository>()) {
      await sl<NotificationsRepository>().simulateIncoming(notification);
    }

    if (targetMode == currentMode) {
      // Navigate inline if we have a router context; otherwise stash so the
      // current shell consumes it on next frame.
      if (context != null && context.mounted) {
        Navigator.of(context).pushNamed(notification.route);
      } else {
        savePendingRoute(
          notification.route,
          targetMode.name,
          kind: notification.kind.code,
        );
      }
      return;
    }

    savePendingRoute(
      notification.route,
      targetMode.name,
      kind: notification.kind.code,
    );

    if (context != null && context.mounted) {
      // Defer the mode switch to the next frame so the calling listener has
      // returned before the widget tree is rebuilt.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) switchAppMode(context, targetMode);
      });
    }
  }
}
