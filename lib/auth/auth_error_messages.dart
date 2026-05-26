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
      return "Telefon raqam noto'g'ri formatda";
    case 'rate_limited':
      final retry = error.retryAfterSeconds;
      if (retry != null) {
        return "Juda ko'p urinish. $retry soniyadan keyin qayta urining";
      }
      return tr('auth.too_many_requests');
    case 'invalid_code':
      return "Kod noto'g'ri";
    case 'otp_expired':
      return "Kodning muddati o'tgan. Qayta yuborishni so'rang";
    case 'otp_attempts_exhausted':
      return "Juda ko'p noto'g'ri urinish. Kodni qayta yuborishni so'rang";
    case 'invalid_refresh_token':
      return tr('auth.invalid_credentials');
    case 'not_authenticated':
      return tr('auth.invalid_credentials');
    case 'validation_error':
      return "Ma'lumotlar noto'g'ri kiritilgan";
    case 'network_error':
      return tr('error.network');
  }
  if (error.status >= 500) return tr('error.network');
  return error.message ?? tr('error.network');
}
