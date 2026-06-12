import 'dart:async';

import '../i18n/i18n.dart';
import 'api_error.dart';

/// Maps an [ApiError] (or any thrown object) to a localised, user-facing
/// message. Blocs/cubits should surface this instead of `e.toString()` so the
/// user never sees a raw English `DioException` / stack-flavoured string in a
/// uz/ru UI. Keys live under the `error.*` namespace in all three bundles.
String apiErrorMessage(Object error) {
  if (error is ApiError) {
    if (error.isRateLimited) return tr('error.rate_limited');
    if (error.isForbidden) return tr('error.forbidden');
    if (error.isValidation) return tr('error.validation_error');
    if (error.status == 0 || error.code == 'network_error') {
      return tr('error.network');
    }
    if (error.status >= 500) return tr('error.server');
    return tr('error.unknown');
  }
  // A bloc-level `.timeout(...)` (e.g. the home feed's 5s ceiling) throws this;
  // treat it as a connectivity problem, not a generic crash.
  if (error is TimeoutException) return tr('error.network');
  return tr('error.unknown');
}
