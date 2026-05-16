import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:woody_app/core/i18n/i18n.dart';

/// Maps an error thrown by a Supabase auth call to a localized, user-facing
/// message.
///
/// Known stable [AuthException] codes get a translated string; an
/// unrecognised [AuthException] falls back to its own (English) message; a
/// non-auth error — almost always a dropped connection — maps to the generic
/// network-error string. Logging the raw error is the caller's job (via
/// `talker.handle`); this helper only decides what the user sees.
String authErrorMessage(Object error) {
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
      case 'invalid_grant':
        return tr('auth.invalid_credentials');
      case 'email_not_confirmed':
        return tr('auth.email_not_confirmed');
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
      case 'over_sms_send_rate_limit':
        return tr('auth.too_many_requests');
      case 'user_already_exists':
      case 'email_exists':
        return tr('auth.email_in_use');
      case 'weak_password':
        return tr('auth.weak_password');
    }
    // A connection dropped mid-request surfaces as a retryable fetch
    // exception with no stable `code` — treat it as a network error.
    if (error is AuthRetryableFetchException) return tr('error.network');
    return error.message;
  }
  // Non-AuthException ⇒ almost always a transport/socket failure.
  return tr('error.network');
}

/// True when [error] means the account exists but its email is unconfirmed.
/// The login screen routes these users to the resend screen instead of
/// showing a dead-end snackbar.
bool isEmailNotConfirmed(Object error) =>
    error is AuthException && error.code == 'email_not_confirmed';
