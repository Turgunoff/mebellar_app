import '../di/service_locator.dart';
import '../notifications/push_service.dart';
import 'auth_repository.dart';

/// Centralised sign-out that clears the device's FCM token from the backend
/// *before* invalidating the access token. Sending the DELETE first lets it
/// hit the `device_tokens` endpoint while we're still authenticated; clearing
/// the token first would 401 the request.
///
/// All sign-out paths in the app (Profile screen button, the 401 auto-logout
/// path on permanent refresh failure, account deletion fallback) should
/// funnel through this helper.
Future<void> signOutWithPushCleanup(AuthRepository repo) async {
  if (sl.isRegistered<PushService>()) {
    await sl<PushService>().removeCurrentToken();
  }
  await repo.signOut();
}
