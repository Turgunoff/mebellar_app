import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/app_mode.dart';
import '../../shared/models/app_notification.dart';
import '../../shared/repositories/notifications_repository.dart';
import '../auth/app_mode_cubit.dart';
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

  /// Entry point for an FCM push tap (background or cold start). Stashes the
  /// destination keyed by [mode] so the matching shell consumes it via
  /// [consumeFor] on its next frame, and — when [mode] differs from the
  /// running app mode — requests the mode switch that brings that shell up.
  ///
  /// Context-free on purpose: the FCM handlers fire without a BuildContext.
  /// `switchMode` only *emits*; the root `BlocListener<AppModeCubit>` in
  /// `main.dart` owns the GetIt scope swap + `Phoenix.rebirth`, and the
  /// freshly-mounted target shell consumes the route via [consumeFor] on its
  /// first frame. Mirrors the in-app inbox tap path in
  /// `notifications_screen._handleTap`.
  ///
  /// The switch is **deferred to the next frame** for a load-bearing reason:
  /// `bootstrap()` is fired with `unawaited`, so a cold-start launch push read
  /// via `getInitialMessage()` can reach this method *before* `runApp()` has
  /// mounted the root `BlocListener` — emitting synchronously there would be
  /// lost (a `BlocListener` ignores pre-subscription transitions), leaving the
  /// app to rebuild the target shell against the still-old GetIt scope. A
  /// post-frame callback only ever runs after a frame has rendered, i.e. after
  /// `runApp()` mounted that listener, so the emit is always observed. On the
  /// first build the cubit still reports the boot mode, so that build stays
  /// scope-consistent; the rebirth follows on the listener's frame.
  void routeFromPush({
    required String route,
    required String mode,
    String? kind,
  }) {
    savePendingRoute(route, mode, kind: kind);
    if (!sl.isRegistered<AppModeCubit>()) return;
    final target = AppMode.fromName(mode);
    if (sl<AppModeCubit>().state == target) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (sl.isRegistered<AppModeCubit>() &&
          sl<AppModeCubit>().state != target) {
        sl<AppModeCubit>().switchMode(target);
      }
    });
    // `addPostFrameCallback` only runs if a frame is actually produced. A
    // tray-push tap can fire while the app is idle (no animation, nothing
    // dirty), in which case no frame would be scheduled and the deferred
    // switch would never run. Force one so the callback is guaranteed to fire.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Returns the pending destination once — the route plus the notification
  /// `kind` that produced it (so the consuming shell can refresh any state
  /// the notification invalidated, e.g. a seller verdict → `/me` refetch) —
  /// or `null` if there is none or it is stale. Always clears the saved
  /// value.
  ({String route, String? kind})? consumeFor(String mode) {
    final route = _pendingRoute.get(_routeKey) as String?;
    final savedMode = _pendingRoute.get(_modeKey) as String?;
    final tsRaw = _pendingRoute.get(_tsKey) as String?;
    final kind = _pendingRoute.get(_kindKey) as String?;

    // Nothing usable — clear any partial debris and bail.
    if (route == null || savedMode == null || tsRaw == null) {
      _clearPending();
      return null;
    }
    // Expired: GC it regardless of which mode it targeted.
    final ts = DateTime.tryParse(tsRaw);
    if (ts == null || DateTime.now().difference(ts) > _staleAfter) {
      _clearPending();
      return null;
    }
    // Fresh route for the OTHER mode: leave it in place. A cross-mode push
    // stashes the destination keyed to the *target* mode and kicks off a
    // Phoenix rebirth (see [routeFromPush]); the outgoing shell's
    // resume-consume races that rebirth and would otherwise wipe the route
    // before the target shell mounts. Only the matching shell clears it.
    if (savedMode != mode) return null;

    _clearPending();
    return (route: route, kind: kind);
  }

  void _clearPending() {
    _pendingRoute.delete(_routeKey);
    _pendingRoute.delete(_modeKey);
    _pendingRoute.delete(_tsKey);
    _pendingRoute.delete(_kindKey);
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
