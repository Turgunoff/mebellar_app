import 'dart:async';

import '../di/service_locator.dart';
import '../network/token_store.dart';
import '../network/woody_api_client.dart';

/// Re-validates the signed-in session against the backend when the app returns
/// to the foreground.
///
/// The per-request auth gate ([WoodyApiClient] → backend `require_user`) already
/// kicks a deleted/blocked account out on its NEXT authenticated call. But a
/// user sitting on an already-painted screen (app resumed from background) makes
/// no such call until they interact, so they could keep viewing stale data. This
/// fires one cheap authenticated probe (`GET /me`) on resume: if the account was
/// deleted/blocked while backgrounded, the backend answers 401 `account_inactive`
/// and the [WoodyApiClient] interceptor turns that into a full force-logout
/// (token + local-data wipe + redirect to the guest surface). A live session
/// just gets a 200.
///
/// Fire-and-forget and guest-safe: skipped entirely when there are no tokens,
/// and errors are swallowed so a network blip never logs anyone out — only an
/// actual 401 from the gate does, via the interceptor.
void revalidateSessionOnResume() {
  if (!sl.isRegistered<TokenStore>() || !sl.isRegistered<WoodyApiClient>()) {
    return;
  }
  // No session → guest; nothing to validate.
  if (sl<TokenStore>().current == null) return;
  unawaited(
    sl<WoodyApiClient>().get<dynamic>('/me').catchError((_) => null),
  );
}
