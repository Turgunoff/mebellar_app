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
  // The app process is dead at this point, so there is no Hive / talker
  // available. The system tray will show the notification automatically
  // because the payload uses a `notification` block; we just need this handler
  // to exist so the plugin doesn't drop the message.
  await Firebase.initializeApp();
}

class PushService {
  PushService({
    required MessagingFacade messaging,
    required FlutterLocalNotificationsPlugin localNotifications,
    required NotificationHandler notificationHandler,
    WoodyApiClient? woodyApi,
  }) : _messaging = messaging,
       _localNotifications = localNotifications,
       _notificationHandler = notificationHandler,
       _woodyApi = woodyApi;

  final MessagingFacade _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final NotificationHandler _notificationHandler;

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
  /// `route` and optional `mode` from the message data payload and stashes
  /// them via [NotificationHandler] so the active app shell consumes them
  /// on the next frame. If the target mode differs from the running mode,
  /// the handler also flips `app_mode` for Phoenix-rebirth on next boot.
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
    _notificationHandler.savePendingRoute(route, modeName, kind: kind);
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
    if (kind == 'seller_approved' || kind == 'seller_rejected') {
      return ('/profile', AppMode.customer.name);
    }
    return (route, modeName);
  }

  Future<void> _initLocalNotifications() async {
    // Android side wants an icon resource that exists in the launcher
    // mipmaps; @mipmap/ic_launcher always exists since flutter_launcher_icons
    // generates it, so it is the safest default.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
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
    if (!kIsWeb && Platform.isAndroid) {
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
    final androidDetails = AndroidNotificationDetails(
      _kNewsChannelId,
      'Yangiliklar',
      channelDescription: 'Yangiliklar va aksiyalar haqida bildirishnomalar',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      // Tag forces every notification to occupy its own tray slot even when
      // bodies are identical (e.g. 3 rapid order-update pings) — without
      // this, Android's auto-grouping replaces older entries on some OEM
      // skins.
      tag: message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}',
    );
    final details = NotificationDetails(android: androidDetails);
    // Wrap to stay inside Android's 32-bit signed int id range. The counter
    // pattern guarantees uniqueness within a process; the tag above
    // provides cross-process uniqueness once the channel is reused.
    final id = (_localNotificationCounter++) & 0x7FFFFFFF;
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
      if (route == '/profile') {
        GoRouter.of(ctx).go('/?tab=profile');
        return;
      }
      // push, not go — keep home underneath so Back returns to it.
      GoRouter.of(ctx).push(route);
      return;
    }
    _notificationHandler.savePendingRoute(route, modeName, kind: kind);
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
