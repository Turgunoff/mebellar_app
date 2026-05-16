import 'package:firebase_messaging/firebase_messaging.dart';

/// Testable seam over the `firebase_messaging` plugin (ROADMAP B.5).
///
/// FCM mixes instance methods on `FirebaseMessaging.instance` with *static*
/// stream getters (`onMessage`, `onMessageOpenedApp`). Those static streams in
/// particular make `PushService` impossible to unit-test against the real
/// plugin. This facade funnels both kinds behind one injectable interface so a
/// fake can drive the whole push pipeline in tests. The plugin value types
/// ([RemoteMessage], [NotificationSettings]) are plain data and re-used as-is.
abstract class MessagingFacade {
  /// Pushes delivered while the app is in the foreground.
  Stream<RemoteMessage> get onMessage;

  /// A push tapped while the app was backgrounded.
  Stream<RemoteMessage> get onMessageOpenedApp;

  /// FCM rotated the registration token.
  Stream<String> get onTokenRefresh;

  /// The push that cold-started the app (consumed once), or `null`.
  Future<RemoteMessage?> getInitialMessage();

  Future<String?> getToken();

  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  });

  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  });

  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
}

/// Production implementation — delegates to the `firebase_messaging` plugin.
class FirebaseMessagingFacade implements MessagingFacade {
  FirebaseMessagingFacade({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  }) =>
      _messaging.requestPermission(alert: alert, badge: badge, sound: sound);

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) =>
      _messaging.setForegroundNotificationPresentationOptions(
        alert: alert,
        badge: badge,
        sound: sound,
      );

  @override
  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);

  @override
  Future<void> unsubscribeFromTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);
}
