import 'package:woody_app/core/i18n/i18n.dart';

import '../core/network/api_error.dart';

/// Maps a Woody-backend [ApiError] code to a localized, user-facing message.
///
/// Codes mirror `app/api/v1/auth.py::_translate` in woody_backend — keep this
/// switch in sync when adding new ones. Unknown codes fall back to a generic
/// network-error string. Logging the raw error is the caller's job (via
/// `talker.handle`); this helper only decides what the user sees.
String authErrorMessageFromApi(ApiError error) {
  switch (error.code) {
    case 'invalid_phone':
      return tr('auth.err_invalid_phone');
    case 'rate_limited':
      final retry = error.retryAfterSeconds;
      if (retry != null) {
        return tr(
          'auth.err_rate_limited_retry',
          namedArgs: {'seconds': '$retry'},
        );
      }
      return tr('auth.too_many_requests');
    case 'invalid_code':
      return tr('auth.err_invalid_code');
    case 'otp_expired':
      return tr('auth.err_otp_expired');
    case 'otp_attempts_exhausted':
      return tr('auth.err_otp_attempts');
    case 'account_blocked':
      return tr('auth.err_account_blocked');
    case 'invalid_refresh_token':
      return tr('auth.invalid_credentials');
    case 'not_authenticated':
      return tr('auth.invalid_credentials');
    case 'validation_error':
      return tr('auth.err_validation');
    case 'network_error':
      return tr('error.network');
  }
  // A 5xx is the SERVER failing, not the user's connection — don't tell them
  // to "check your internet". Real no-response failures hit `network_error`.
  if (error.status >= 500) return tr('error.server');
  return error.message ?? tr('error.network');
}
