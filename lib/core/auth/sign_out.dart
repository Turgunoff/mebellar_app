import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../notifications/push_service.dart';

/// Centralised sign-out that clears the device's FCM token from
/// `device_tokens` *before* invalidating the Supabase session. Calling
/// `supabase.auth.signOut()` first would clear the JWT, after which RLS
/// rejects the delete and the row is left orphaned (eventually garbage-
/// collected when the auth.users row is removed, but stale until then).
///
/// All sign-out paths in the app (the Profile screen button, the 401 auto-
/// logout in the Dio interceptor, the ghost-session recovery in
/// ProfileCubit, etc.) should funnel through this helper. Account deletion
/// is the one exception — `delete_user_account` removes the auth.users row
/// and the `on delete cascade` already wipes device_tokens.
Future<void> signOutWithPushCleanup(SupabaseClient supabase) async {
  if (sl.isRegistered<PushService>()) {
    await sl<PushService>().removeCurrentToken();
  }
  await supabase.auth.signOut();
}
