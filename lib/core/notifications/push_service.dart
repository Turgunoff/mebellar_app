import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/notification_model.dart';
import '../logging/talker.dart';

/// FCM topic the app subscribes to for marketing / news pushes.
/// Sending to this topic from the Firebase Console (or HTTP v1 API) reaches
/// every install that has notifications enabled.
const String kNewsTopic = 'news';

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
    required SupabaseClient? supabase,
  })  : _messaging = messaging,
        _supabase = supabase;

  final FirebaseMessaging _messaging;
  final SupabaseClient? _supabase;

  bool _initialised = false;

  /// Bootstraps FCM:
  ///   1. requests notification permission (iOS + Android 13+)
  ///   2. subscribes to the `news` topic so promo broadcasts are delivered
  ///   3. wires the foreground handler so a push received while the app is
  ///      open mirrors into the in-app inbox
  ///
  /// Safe to call multiple times — the second invocation is a no-op.
  Future<void> initialise() async {
    if (_initialised) return;
    _initialised = true;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      talker.info(
        'FCM permission: ${settings.authorizationStatus.name}',
      );
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

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    } catch (e, st) {
      talker.handle(e, st, 'PushService.initialise failed');
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

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    talker.info('FCM foreground: ${notification.title}');

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
