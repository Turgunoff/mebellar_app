import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_mode.dart';
import '../../shared/models/notification_model.dart';
import '../logging/talker.dart';
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
  // The app process is dead at this point, so there is no Supabase / Hive /
  // talker available. The system tray will show the notification automatically
  // because the payload uses a `notification` block; we just need this handler
  // to exist so the plugin doesn't drop the message.
  await Firebase.initializeApp();
}

class PushService {
  PushService({
    required FirebaseMessaging messaging,
    required FlutterLocalNotificationsPlugin localNotifications,
    required NotificationHandler notificationHandler,
    required SupabaseClient? supabase,
  })  : _messaging = messaging,
        _localNotifications = localNotifications,
        _notificationHandler = notificationHandler,
        _supabase = supabase;

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final NotificationHandler _notificationHandler;
  final SupabaseClient? _supabase;

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
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTapped);
    // Cold-start path: when the app is launched from a tap on a tray
    // notification (process was killed), `getInitialMessage` returns that
    // message exactly once. Stash the route so the customer/seller shell
    // consumes it on first frame, mirroring the in-app simulator flow.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _onMessageTapped(initial);
    // FCM rotates tokens occasionally (app data wipe, restore, etc.). When
    // it does, re-save the new token under the currently logged-in user so
    // the server-side sender keeps reaching this device.
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      final userId = _supabase?.auth.currentUser?.id;
      if (userId == null) return;
      await _upsertToken(token: token, userId: userId);
    });
  }

  /// Invoked when the user taps a push (background or cold start). Reads
  /// `route` and optional `mode` from the message data payload and stashes
  /// them via [NotificationHandler] so the active app shell consumes them
  /// on the next frame. If the target mode differs from the running mode,
  /// the handler also flips `app_mode` for Phoenix-rebirth on next boot.
  void _onMessageTapped(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route == null || route.isEmpty) return;
    final modeName = (message.data['mode'] as String?) ?? AppMode.customer.name;
    debugPrint('[FCM] push tapped → route: $route (mode: $modeName)');
    _notificationHandler.savePendingRoute(
      route,
      modeName,
      kind: message.data['kind'] as String?,
    );
  }

  Future<void> _initLocalNotifications() async {
    // Android side wants an icon resource that exists in the launcher
    // mipmaps; @mipmap/ic_launcher always exists since flutter_launcher_icons
    // generates it, so it is the safest default.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(init);

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
            AndroidFlutterLocalNotificationsPlugin>()
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
      talker.info(
        'FCM permission: ${settings.authorizationStatus.name}',
      );
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
    } catch (e, st) {
      // Reset so a manual retry (e.g. settings toggle later) can re-prompt.
      _permissionRequested = false;
      talker.handle(e, st, 'PushService.requestPermissionAndSubscribe failed');
    }
  }

  /// Stop receiving the news topic — call from logout / "disable news"
  /// preference toggle if we add one later.
  Future<void> unsubscribeFromNews() async {
    try {
      await _messaging.unsubscribeFromTopic(kNewsTopic);
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
    if (_supabase == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        talker.warning('FCM getToken returned null — skipping sync');
        debugPrint('[FCM] getToken returned null — skipping sync');
        return;
      }
      debugPrint('[FCM] token (first 24): ${token.substring(0, 24)}...');
      await _upsertToken(token: token, userId: userId);
    } catch (e, st) {
      talker.handle(e, st, 'PushService.syncTokenForUser failed');
      debugPrint('[FCM] syncTokenForUser failed: $e');
    }
  }

  /// Deletes this device's token from the DB. Must be invoked **before**
  /// `supabase.auth.signOut()` — once the session is cleared, RLS denies the
  /// delete and the row is orphaned (eventually GC'd via the cascade when
  /// the user account is deleted, but stale until then).
  Future<void> removeCurrentToken() async {
    if (_supabase == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _supabase
          .from('device_tokens')
          .delete()
          .eq('token', token);
      talker.info('FCM token removed from device_tokens');
      debugPrint('[FCM] token removed from device_tokens');
    } catch (e, st) {
      talker.handle(e, st, 'PushService.removeCurrentToken failed');
    }
  }

  Future<void> _upsertToken({
    required String token,
    required String userId,
  }) async {
    if (_supabase == null) return;
    final platform = _platformLabel();
    await _supabase.from('device_tokens').upsert({
      'token': token,
      'user_id': userId,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
    talker.info('FCM token saved (platform=$platform)');
    debugPrint('[FCM] token saved to device_tokens (platform=$platform, user=$userId)');
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
    debugPrint('[FCM] foreground push received: "${notification.title}" — "${notification.body}"');

    // Android suppresses tray notifications when the app is in the
    // foreground — re-post via flutter_local_notifications so the user
    // actually sees the ping. iOS already handles this through the
    // setForegroundNotificationPresentationOptions call in
    // requestPermissionAndSubscribe(), so we only re-post on Android.
    if (!kIsWeb && Platform.isAndroid) {
      await _showLocalNotification(message);
    }

    // Mirror into the Supabase inbox so the bell-icon screen renders the
    // entry. We can only insert when authenticated — anonymous users keep
    // the system tray notification only.
    final user = _supabase?.auth.currentUser;
    if (user == null || _supabase == null) return;
    try {
      await _supabase.from('notifications').insert({
        'user_id': user.id,
        'title': notification.title ?? '',
        'body': notification.body ?? '',
        'is_read': false,
      });
    } catch (e, st) {
      talker.handle(e, st, 'PushService inbox mirror failed');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    const androidDetails = AndroidNotificationDetails(
      _kNewsChannelId,
      'Yangiliklar',
      channelDescription: 'Yangiliklar va aksiyalar haqida bildirishnomalar',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    // The FCM message id is unique per push; use its hashCode as the
    // local-notification id so multiple pushes don't overwrite each other
    // in the tray.
    final id = (message.messageId ?? DateTime.now().toIso8601String()).hashCode;
    await _localNotifications.show(id, n.title, n.body, details);
  }

  /// Exposed so debug tooling (push simulator screen) can preview a payload
  /// without needing FCM credentials.
  @visibleForTesting
  NotificationModel previewFromMessage(RemoteMessage message) {
    final n = message.notification;
    return NotificationModel(
      id: message.messageId ?? DateTime.now().toIso8601String(),
      userId: _supabase?.auth.currentUser?.id ?? 'guest',
      title: n?.title ?? '',
      body: n?.body ?? '',
      isRead: false,
      createdAt: DateTime.now(),
    );
  }
}
