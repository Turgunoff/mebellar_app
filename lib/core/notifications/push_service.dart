import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_mode.dart';
import '../../shared/models/notification_model.dart';
import '../logging/talker.dart';
import '../network/api_error.dart';
import '../network/woody_api_client.dart';
import '../platform/messaging_facade.dart';
import 'active_chat_tracker.dart';
import 'active_support_tracker.dart';
import 'app_badge_service.dart';
import 'notification_handler.dart';

/// FCM topic the app subscribes to for marketing / news pushes.
/// Sending to this topic from the Firebase Console (or HTTP v1 API) reaches
/// every install that has notifications enabled.
const String kNewsTopic = 'news';

/// Android notification channel id. Must match the
/// `default_notification_channel_id` meta-data in AndroidManifest.xml so
/// the OS routes background pushes through the same channel that
/// `flutter_local_notifications` uses for foreground display — otherwise
/// the user would see two separate "categories" in app settings and
/// silencing one would not silence the other.
const String _kNewsChannelId = 'news';

/// Background isolate entrypoint. FCM requires a top-level (or static)
/// function annotated with @pragma so it survives tree-shaking.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The app process is dead at this point, so there is no Hive / talker / DI /
  // cubits available. The system tray shows the notification automatically
  // because the payload uses a `notification` block; this handler must exist so
  // the plugin doesn't drop the message.
  await Firebase.initializeApp();

  // Bump the launcher app-icon badge so the icon reflects the new item even
  // though no app state is reachable here. Gated to user-facing pushes (those
  // carrying a `notification` block or a `kind`) so a silent data-only ping
  // doesn't inflate the count. The live app reconciles this naive +1 tally to
  // the true unread total on next resume (BadgeSyncController).
  //
  // iOS note: a terminated-app `notification` push usually doesn't run this
  // Dart handler — iOS sets the badge natively from the APNs `badge` field
  // instead (see the backend note in requestPermissionAndSubscribe), so this
  // path is primarily the Android one.
  final hasUserFacingPayload =
      message.notification != null ||
      ((message.data['kind'] as String?)?.isNotEmpty ?? false);
  if (hasUserFacingPayload) {
    // Prefer the backend's authoritative unread total when the payload carries
    // it (every Woody push now does) — exact, drift-free. Fall back to the
    // naive +1 only for legacy pushes that predate the `unread_count` field.
    final unread = _unreadCountFromData(message.data);
    if (unread != null) {
      await setAppBadgeFromBackground(unread);
    } else {
      await incrementAppBadgeFromBackground();
    }
  }
}

/// Parses the backend's `unread_count` (the server-computed launcher-badge
/// total) out of an FCM data payload. Returns null when the key is absent
/// (legacy push) or non-numeric, so callers can fall back to a blind +1. The
/// value arrives as a string — FCM's data map is `Map<String, String>`.
int? _unreadCountFromData(Map<String, dynamic> data) {
  final raw = data['unread_count'];
  if (raw == null) return null;
  final parsed = int.tryParse(raw.toString());
  if (parsed == null || parsed < 0) return null;
  return parsed;
}

class PushService {
  PushService({
    required MessagingFacade messaging,
    required FlutterLocalNotificationsPlugin localNotifications,
    required NotificationHandler notificationHandler,
    WoodyApiClient? woodyApi,
    AppBadgeService? badge,
  }) : _messaging = messaging,
       _localNotifications = localNotifications,
       _notificationHandler = notificationHandler,
       _woodyApi = woodyApi,
       _badge = badge;

  final MessagingFacade _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final NotificationHandler _notificationHandler;

  /// Crash-proof launcher-badge writer. Null only in unit tests that don't
  /// exercise badging; the live app always injects the root singleton so a
  /// foreground push can set the icon count immediately (ahead of the inbox
  /// reload that `BadgeSyncController` would otherwise wait on).
  final AppBadgeService? _badge;

  /// Device-token registration calls the Woody REST endpoint
  /// (`POST /push/device-tokens`). Null only in builds without a configured
  /// Woody backend (unit tests), where token sync is skipped.
  final WoodyApiClient? _woodyApi;

  bool _bootstrapped = false;
  bool _permissionRequested = false;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Wires every FCM-related listener and initialises the local
  /// notifications plugin. Called once at app boot:
  ///
  ///   * `onMessage`         — foreground pushes (re-posted via local
  ///                           notification so they show in the tray)
  ///   * `onMessageOpenedApp` — push tapped while app was in background
  ///   * `getInitialMessage` — push tapped while app was killed
  ///                           (the launching push is consumed once)
  ///   * `onTokenRefresh`     — FCM rotates the token (app reinstall, etc.)
  ///
  /// Safe to call multiple times.
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await _initLocalNotifications();
    _messaging.onMessage.listen(_onForegroundMessage);
    _messaging.onMessageOpenedApp.listen(_onMessageTapped);
    // Cold-start path: when the app is launched from a tap on a tray
    // notification (process was killed), `getInitialMessage` returns that
    // message exactly once. Stash the route so the customer/seller shell
    // consumes it on first frame, mirroring the in-app simulator flow.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _onMessageTapped(initial);
    // FCM rotates tokens occasionally (app data wipe, restore, etc.). When
    // it does, re-save the new token under the currently logged-in user so
    // the server-side sender keeps reaching this device.
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_onTokenRefreshed);
  }

  /// Invoked when the user taps a push (background or cold start). Reads
  /// `route` and optional `mode` from the message data payload and hands them
  /// to [NotificationHandler.routeFromPush], which stashes the destination so
  /// the matching shell consumes it on its next frame and — when the target
  /// mode differs from the running mode — requests the mode switch that
  /// brings that shell up (GetIt scope swap + Phoenix rebirth).
  void _onMessageTapped(RemoteMessage message) {
    var route = message.data['route'] as String?;
    if (route == null || route.isEmpty) return;
    var modeName = (message.data['mode'] as String?) ?? AppMode.customer.name;
    final kind = message.data['kind'] as String?;
    (route, modeName) = _sanitizeDestination(
      kind: kind,
      route: route,
      modeName: modeName,
    );
    debugPrint('[FCM] push tapped → route: $route (mode: $modeName)');
    _notificationHandler.routeFromPush(
      route: route,
      mode: modeName,
      kind: kind,
    );
  }

  /// Verification verdicts must always land on the customer profile — the
  /// payload of pushes sent before backend migration 0019 carries a stale
  /// `mode: seller` + `/seller/profile` that would drop a rejected applicant
  /// into the seller shell. Mirrors `NotificationModel.resolveTargetMode`.
  static (String, String) _sanitizeDestination({
    required String? kind,
    required String route,
    required String modeName,
  }) {
    if (NotificationKind.fromString(kind).isSellerVerdict) {
      return ('/profile', AppMode.customer.name);
    }
    // Support pushes carry `route="support"` (no leading slash) + the customer
    // mode. Normalise to the GoRoute path so a tap deep-links to the thread.
    if (kind == _supportMessageKind || route == 'support') {
      return ('/support', AppMode.customer.name);
    }
    return (route, modeName);
  }

  /// True when [message] is a chat push for the exact thread the user is
  /// currently viewing. Matches on chat id rather than the raw route so it
  /// works regardless of which path opened the thread (`/chats/:id`,
  /// `/seller/chats/:id`, or `/seller/orders/:id/chat`). The chat id is read
  /// from the push `route` (the same field tap-navigation relies on, so it's
  /// always the thread route) or an explicit `chat_id` field.
  bool _isViewingPushedChat(RemoteMessage message) {
    if (NotificationKind.fromString(message.data['kind'] as String?) !=
        NotificationKind.chatMessage) {
      return false;
    }
    final chatId =
        (message.data['chat_id'] as String?) ??
        _chatIdFromRoute(message.data['route'] as String?);
    return ActiveChatTracker.instance.isViewing(chatId);
  }

  /// Push payload `kind` for a support-chat message. The backend sends the
  /// literal `"support_message"` (NOT a [NotificationKind] code), so it's
  /// matched as a raw string rather than through the enum.
  static const String _supportMessageKind = 'support_message';

  /// The Android tray `tag` (and iOS thread) every support notification
  /// carries. Static — support is one per-user thread — so repeat messages
  /// collapse to a single tray entry and [dismissSupportNotifications] can find
  /// them. MUST match the backend's `android_tag` (`support`).
  static const String supportNotificationTag = 'support';

  /// Stable notification id for the (single) support thread — a fixed value so
  /// the OS replaces (not stacks) the support entry and we can cancel it by id.
  static const int supportNotificationId = 0x53555050; // 'SUPP'

  /// True when [message] is a support push while the support thread is on
  /// screen — the open thread already shows the message live over the WS, so
  /// the foreground re-post is just noise.
  bool _isViewingPushedSupport(RemoteMessage message) {
    if (message.data['kind'] != _supportMessageKind) return false;
    return ActiveSupportTracker.instance.isViewing;
  }

  /// Clears the support tray notification(s) — our foreground re-post plus any
  /// OS-shown background push (both tagged `support`). Call when the support
  /// thread is opened/read.
  Future<void> dismissSupportNotifications() async {
    try {
      await _localNotifications.cancel(
        supportNotificationId,
        tag: supportNotificationTag,
      );
      if (!kIsWeb && Platform.isAndroid) {
        final active = await _localNotifications.getActiveNotifications();
        for (final n in active) {
          if (n.tag == supportNotificationTag && n.id != null) {
            await _localNotifications.cancel(n.id!, tag: n.tag);
          }
        }
      }
    } catch (e, st) {
      talker.handle(e, st, 'PushService.dismissSupportNotifications failed');
    }
  }

  /// Extracts the chat id from a `…/chats/<id>` route, or null if the route
  /// isn't a chat thread path.
  static String? _chatIdFromRoute(String? route) {
    if (route == null || route.isEmpty) return null;
    final segments = Uri.parse(route).pathSegments;
    final i = segments.indexOf('chats');
    if (i >= 0 && i + 1 < segments.length) return segments[i + 1];
    return null;
  }

  /// The Android tray `tag` (and iOS thread) every notification for [chatId]
  /// carries. Deterministic so repeat messages collapse to one entry and
  /// [dismissChatNotifications] can find them. MUST match the backend's
  /// `android_tag` (`chat:<chat_id>` in `ChatRepository._push_chat_message`).
  static String chatNotificationTag(String chatId) => 'chat:$chatId';

  /// A stable 31-bit notification id for [chatId]. `String.hashCode` isn't
  /// guaranteed stable across launches, and a chat push must reuse the same
  /// id every time so the OS replaces (not stacks) the chat's tray entry and
  /// so we can cancel it by id. FNV-1a keeps it cheap + deterministic; masked
  /// into the positive half of Android's signed 32-bit id space.
  static int chatNotificationId(String chatId) {
    var hash = 0x811c9dc5;
    for (final unit in chatId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// Clears every tray notification for [chatId] — the foreground re-posts we
  /// showed plus the OS-shown background pushes (both tagged
  /// `chat:<id>` via [chatNotificationTag] / the backend). Call when the
  /// thread is opened/read so a notification the user has already acted on
  /// doesn't linger in the tray.
  ///
  /// Android: cancel our deterministic (id, tag), then sweep
  /// `getActiveNotifications()` for any sibling carrying the same tag — an
  /// FCM-posted entry uses its *own* id, so a blind `cancel(id)` would miss
  /// it; matching on the shared tag catches it regardless of who posted it.
  /// iOS: cancel our id and rely on `apns-collapse-id` (set backend-side)
  /// keeping a chat to a single entry — the plugin can't enumerate remote
  /// pushes by chat there, so background ones clear on tap.
  Future<void> dismissChatNotifications(String chatId) async {
    if (chatId.isEmpty) return;
    final tag = chatNotificationTag(chatId);
    try {
      await _localNotifications.cancel(chatNotificationId(chatId), tag: tag);
      if (!kIsWeb && Platform.isAndroid) {
        final active = await _localNotifications.getActiveNotifications();
        for (final n in active) {
          if (n.tag == tag && n.id != null) {
            await _localNotifications.cancel(n.id!, tag: n.tag);
          }
        }
      }
    } catch (e, st) {
      // Best-effort — a failed clear just leaves a stale tray entry, never
      // worth bubbling up if a platform-channel call happens to throw.
      talker.handle(e, st, 'PushService.dismissChatNotifications failed');
    }
  }

  Future<void> _initLocalNotifications() async {
    // Status-bar notification icon: a white-on-transparent silhouette
    // (ic_stat_woody). A full-colour @mipmap/ic_launcher would render as a
    // white square here, since Android draws only the icon's alpha channel.
    const androidInit = AndroidInitializationSettings(
      '@drawable/ic_stat_woody',
    );
    // iOS requires Darwin settings or initialize() throws. We don't request
    // permissions here (requestPermissionAndSubscribe does that via FCM); the
    // OS shows foreground pings itself through
    // setForegroundNotificationPresentationOptions, so iOS never re-posts.
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const init = InitializationSettings(android: androidInit, iOS: darwinInit);
    await _localNotifications.initialize(
      init,
      // Tap on a foreground-reposted notification → route the same way a
      // background FCM tap does.
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Channel must exist before the first notification is shown; without it
    // Android 8+ silently drops the post. The id matches the manifest's
    // default_notification_channel_id so background-tray pushes (handled by
    // FCM) and our foreground re-posts share one channel.
    const channel = AndroidNotificationChannel(
      _kNewsChannelId,
      'Yangiliklar',
      description: 'Yangiliklar va aksiyalar haqida bildirishnomalar',
      importance: Importance.high,
      // OEM launchers (Samsung/Xiaomi/…) only paint an icon badge for channels
      // that allow it. Set explicitly (the plugin default is true, but a
      // channel created with showBadge=false is sticky once registered) so a
      // posted notification can carry its count to the launcher.
      showBadge: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Triggers the OS notification permission dialog and subscribes the
  /// device to the `news` topic on success. Idempotent within a session —
  /// once the user has responded (allow / deny), subsequent calls are a
  /// no-op so we don't re-pester them.
  ///
  /// Call this **after** the user reaches the home screen — never from the
  /// splash or onboarding, where the prompt would feel intrusive and is
  /// known to lower opt-in rates significantly.
  Future<void> requestPermissionAndSubscribe() async {
    if (_permissionRequested) return;
    _permissionRequested = true;

    try {
      // `badge: true` requests the iOS app-icon-badge entitlement alongside
      // alert + sound. Without it, iOS silently drops the APNs `badge` field
      // and `app_badge_plus`/`setApplicationIconBadgeNumber` can't paint a count.
      //
      // BACKEND NOTE (woody_backend FCM/APNs sender): for native iOS badging
      // include an APNs `badge` value in the push payload (the per-user unread
      // total — NOT a hardcoded 1 — so the OS shows the right number and clears
      // it when the count drops). On Android the count is driven from the app
      // (background isolate + BadgeSyncController), so no Android-side payload
      // change is needed.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      talker.info('FCM permission: ${settings.authorizationStatus.name}');
      debugPrint('[FCM] permission: ${settings.authorizationStatus.name}');
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return;

      // Foreground display on iOS: show the system banner even when the app
      // is in the foreground so the user actually sees the news ping.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _messaging.subscribeToTopic(kNewsTopic);
      talker.info('Subscribed to FCM topic: $kNewsTopic');
      debugPrint('[FCM] subscribed to topic: $kNewsTopic');
    } on FirebaseException catch (e, st) {
      // Reset so a manual retry (e.g. settings toggle later) can re-prompt.
      _permissionRequested = false;
      if (_isApnsTokenNotReady(e)) {
        _logApnsNotReady('skipping topic subscribe');
        return;
      }
      talker.handle(e, st, 'PushService.requestPermissionAndSubscribe failed');
    } catch (e, st) {
      // Non-Firebase failure — keep the existing reporting behaviour.
      _permissionRequested = false;
      talker.handle(e, st, 'PushService.requestPermissionAndSubscribe failed');
    }
  }

  /// True when [e] is the benign `apns-token-not-set` thrown by
  /// firebase_messaging's internal `_APNSTokenCheck`. It gates `getToken`,
  /// `subscribeToTopic`, `unsubscribeFromTopic` and `deleteToken` on iOS/macOS
  /// and fires whenever `getAPNSToken()` is still null: *always* on the
  /// Simulator (FCM-over-APNs is unsupported there) and transiently on a real
  /// device during the cold-start race before APNs hands the token back. It is
  /// not a crash — just "no APNs token yet here". We match the error *code*
  /// (the plugin's contract), never the human message; `endsWith` absorbs any
  /// future namespacing ('messaging/apns-token-not-set').
  static bool _isApnsTokenNotReady(FirebaseException e) {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) return false;
    final code = e.code.toLowerCase();
    return code == 'apns-token-not-set' || code.endsWith('apns-token-not-set');
  }

  /// Benign-swallow log for the APNs-not-ready case. Warning level — kept in
  /// the in-app Talker screen but NOT forwarded to Crashlytics (the observer
  /// only bridges talker.handle) and NOT printed (useConsoleLogs:false).
  void _logApnsNotReady(String action) {
    talker.warning('FCM APNs token not ready — $action');
    debugPrint('[FCM] APNs token not set — $action');
  }

  /// Stop receiving the news topic — call from logout / "disable news"
  /// preference toggle if we add one later.
  Future<void> unsubscribeFromNews() async {
    try {
      await _messaging.unsubscribeFromTopic(kNewsTopic);
    } on FirebaseException catch (e, st) {
      if (_isApnsTokenNotReady(e)) {
        _logApnsNotReady('skipping topic unsubscribe');
        return;
      }
      talker.handle(e, st, 'PushService.unsubscribeFromNews failed');
    } catch (e, st) {
      talker.handle(e, st, 'PushService.unsubscribeFromNews failed');
    }
  }

  /// Fetches the current FCM token and upserts it into `device_tokens`
  /// under the given user. Called from the auth flow on sign-in.
  ///
  /// Idempotent — a re-login with the same token just bumps `updated_at`.
  /// Cross-account on the same device works because `token` is the PK,
  /// so the upsert overwrites the prior `user_id`.
  Future<void> syncTokenForUser(String userId) async {
    if (_woodyApi == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        talker.warning('FCM getToken returned null — skipping sync');
        debugPrint('[FCM] getToken returned null — skipping sync');
        return;
      }
      debugPrint('[FCM] token (first 24): ${token.substring(0, 24)}...');
      await _upsertToken(token: token, userId: userId);
    } on FirebaseException catch (e, st) {
      if (_isApnsTokenNotReady(e)) {
        _logApnsNotReady('skipping token sync');
        return;
      }
      talker.handle(e, st, 'PushService.syncTokenForUser failed');
      debugPrint('[FCM] syncTokenForUser failed: $e');
    } catch (e, st) {
      talker.handle(e, st, 'PushService.syncTokenForUser failed');
      debugPrint('[FCM] syncTokenForUser failed: $e');
    }
  }

  /// FCM rotated the registration token (app restore, data wipe, etc.).
  /// Re-registers it under the active session — the Woody JWT carries the user
  /// id, so the upsert needs only the token; it skips silently when no backend
  /// is configured (`_woodyApi` null) or the user is signed out (401, swallowed
  /// in [_upsertToken]).
  ///
  /// Errors are caught and logged as non-fatals, never rethrown: this runs from
  /// a stream listener, so an escaping rejection (offline, a transient 5xx)
  /// would land in `runZonedGuarded` and Crashlytics would record a *fatal* on
  /// every blip. A dropped rotation self-heals — the next launch re-syncs
  /// through [syncTokenForUser] off the restored session.
  Future<void> _onTokenRefreshed(String token) async {
    if (token.isEmpty) return;
    try {
      await _upsertToken(token: token, userId: '');
    } catch (e, st) {
      talker.handle(e, st, 'PushService.onTokenRefresh upsert failed');
    }
  }

  /// Deletes this device's token server-side. Must be invoked **before**
  /// sign-out clears the access token — once the JWT is gone the DELETE gets a
  /// 401 and the row is orphaned (GC'd later via the account-delete cascade).
  Future<void> removeCurrentToken() async {
    if (_woodyApi == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      try {
        await _woodyApi.delete<dynamic>('/push/device-tokens/$token');
      } on ApiError catch (e) {
        if (e.isUnauthorized) return;
        rethrow;
      }
      talker.info('FCM token removed from device_tokens');
      debugPrint('[FCM] token removed from device_tokens');
    } on FirebaseException catch (e, st) {
      if (_isApnsTokenNotReady(e)) {
        _logApnsNotReady('skipping token removal');
        return;
      }
      talker.handle(e, st, 'PushService.removeCurrentToken failed');
    } catch (e, st) {
      talker.handle(e, st, 'PushService.removeCurrentToken failed');
    }
  }

  Future<void> _upsertToken({
    required String token,
    required String userId,
  }) async {
    if (_woodyApi == null) return;
    final platform = _platformLabel();
    try {
      await _woodyApi.post<dynamic>(
        '/push/device-tokens',
        body: {'token': token, 'platform': platform},
      );
      talker.info('FCM token saved via Woody REST (platform=$platform)');
      debugPrint('[FCM] token saved via Woody REST (platform=$platform)');
    } on ApiError catch (e) {
      if (e.isUnauthorized) {
        // Not signed in — defer registration until syncTokenForUser is
        // called after the next sign-in completes.
        return;
      }
      rethrow;
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }

  /// Cancels long-lived subscriptions. Currently only the token-refresh
  /// listener; called when the DI scope hosting this service tears down
  /// (e.g. during a hard logout that pops the customer scope).
  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // Immediate authoritative badge: set the launcher icon from the backend's
    // unread total the instant the push lands, ahead of the inbox-reload round
    // trip BadgeSyncController would otherwise reconcile from. Done before the
    // notification-null guard so a data-only push still updates the count. The
    // controller still re-asserts the mode-specific in-app total right after.
    final unread = _unreadCountFromData(message.data);
    if (unread != null) unawaited(_badge?.setCount(unread) ?? Future.value());

    final notification = message.notification;
    if (notification == null) return;
    talker.info('FCM foreground: ${notification.title}');
    debugPrint(
      '[FCM] foreground push received: "${notification.title}" — "${notification.body}"',
    );

    // Android suppresses tray notifications when the app is in the
    // foreground — re-post via flutter_local_notifications so the user
    // actually sees the ping. iOS already handles this through the
    // setForegroundNotificationPresentationOptions call in
    // requestPermissionAndSubscribe(), so we only re-post on Android.
    //
    // Smart suppression: when the push is for the very chat the user is
    // staring at, skip the re-post entirely — the open thread already shows
    // the message live over the WS, so a drop-down on top of it is just
    // noise (Telegram does the same).
    if (!kIsWeb &&
        Platform.isAndroid &&
        !_isViewingPushedChat(message) &&
        !_isViewingPushedSupport(message)) {
      await _showLocalNotification(message);
    }

    // Belt-and-suspenders inbox sync: the Woody realtime socket should already
    // have surfaced this row to the cubit, but if the socket is momentarily
    // down (network blip, backgrounded) the foreground push is a second nudge
    // to refresh. The notify call is fire-and-forget — any
    // failure is logged inside the cubit and doesn't block the local
    // notification display.
    _onForegroundPush?.call(message);
  }

  /// Optional hook injected by the app shell so that a foreground push can
  /// trigger an inbox refresh. Wired in `main.dart` to call
  /// `NotificationsCubit.load()`. Decoupled via callback so PushService
  /// stays free of feature-layer imports.
  void Function(RemoteMessage message)? _onForegroundPush;
  set onForegroundPush(void Function(RemoteMessage)? cb) =>
      _onForegroundPush = cb;

  /// Monotonically increasing id for local notifications. Two pushes that
  /// arrive in the same millisecond would produce the same hashCode if we
  /// used the timestamp as a string — Android then overwrites the prior
  /// notification instead of stacking them. A simple counter (mod the 32-bit
  /// notification id space) sidesteps that race.
  int _localNotificationCounter = 0;

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    // A chat push reuses a per-chat id + tag so repeat messages from the same
    // conversation collapse to one tray entry (matching the background push,
    // tagged the same way backend-side) and dismissChatNotifications can
    // target them on read. Everything else keeps its own slot via the counter
    // + message-id tag so distinct pings stack instead of replacing.
    final isChat =
        NotificationKind.fromString(message.data['kind'] as String?) ==
        NotificationKind.chatMessage;
    final isSupport = message.data['kind'] == _supportMessageKind;
    final chatId =
        (message.data['chat_id'] as String?) ??
        _chatIdFromRoute(message.data['route'] as String?);
    final useChatSlot = isChat && chatId != null && chatId.isNotEmpty;
    final tag = useChatSlot
        ? chatNotificationTag(chatId)
        : isSupport
        ? supportNotificationTag
        : (message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}');
    // Carry the backend's unread total onto the notification so OEM launchers
    // (Samsung/Xiaomi/MIUI) that derive the icon badge from a posted
    // notification's `number` show the right count — these skins ignore the
    // standalone app_badge_plus broadcast and read the number off the tray.
    final unread = _unreadCountFromData(message.data);
    final androidDetails = AndroidNotificationDetails(
      _kNewsChannelId,
      'Yangiliklar',
      channelDescription: 'Yangiliklar va aksiyalar haqida bildirishnomalar',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_woody',
      // Tag forces every notification to occupy its own tray slot even when
      // bodies are identical (e.g. 3 rapid order-update pings) — without
      // this, Android's auto-grouping replaces older entries on some OEM
      // skins. A chat reuses the per-chat tag so its entries DO collapse.
      tag: tag,
      // Mirror the channel's badge opt-in on the post itself, and stamp the
      // count so launchers that badge off the notification number paint it.
      channelShowBadge: true,
      number: unread,
    );
    final details = NotificationDetails(android: androidDetails);
    // Wrap to stay inside Android's 32-bit signed int id range. The counter
    // pattern guarantees uniqueness within a process; the tag above
    // provides cross-process uniqueness once the channel is reused.
    final id = useChatSlot
        ? chatNotificationId(chatId)
        : isSupport
        ? supportNotificationId
        : ((_localNotificationCounter++) & 0x7FFFFFFF);
    // Carry the FCM data payload so a tap can resolve route + mode.
    await _localNotifications.show(
      id,
      n.title,
      n.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Tap on a foreground-reposted local notification. The app is already alive
  /// (no resume event fires), so navigate immediately when the matching shell
  /// is mounted; otherwise stash the route for the shell to consume on the
  /// next init/resume.
  void _onLocalNotificationTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    var route = data['route'] as String?;
    if (route == null || route.isEmpty) return;
    var modeName = (data['mode'] as String?) ?? AppMode.customer.name;
    final kind = data['kind'] as String?;
    (route, modeName) = _sanitizeDestination(
      kind: kind,
      route: route,
      modeName: modeName,
    );

    final ctx = customerNavigatorKey.currentContext;
    if (modeName == AppMode.customer.name && ctx != null && ctx.mounted) {
      // Tab destinations switch the home-shell tab (mirrors
      // `navigateCustomerRoute` in customer/router.dart — kept inline so the
      // core layer doesn't import the customer router).
      const tabRoutes = {
        '/categories': 'categories',
        '/cart': 'cart',
        '/favorites': 'favorites',
        '/profile': 'profile',
      };
      final tab = tabRoutes[route];
      if (tab != null) {
        GoRouter.of(ctx).go('/?tab=$tab');
        return;
      }
      // push, not go — keep home underneath so Back returns to it.
      GoRouter.of(ctx).push(route);
      return;
    }
    // Not the customer fast-path (cross-mode, or no live customer router):
    // stash + (cross-mode) trigger the switch so the target shell mounts and
    // consumes the route, instead of dropping a push meant for the other mode.
    _notificationHandler.routeFromPush(
      route: route,
      mode: modeName,
      kind: kind,
    );
  }

  /// Exposed so debug tooling (push simulator screen) can preview a payload
  /// without needing FCM credentials.
  @visibleForTesting
  NotificationModel previewFromMessage(RemoteMessage message) {
    final n = message.notification;
    return NotificationModel(
      id: message.messageId ?? DateTime.now().toIso8601String(),
      userId: 'guest',
      title: n?.title ?? '',
      body: n?.body ?? '',
      kind: NotificationKind.fromString(message.data['kind'] as String?),
      referenceId: message.data['reference_id'] as String?,
      isRead: false,
      createdAt: DateTime.now(),
    );
  }
}
