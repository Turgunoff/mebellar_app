import 'dart:async';

import '../error/failure.dart';
import '../i18n/i18n.dart';
import 'api_error.dart';

/// Backend `{detail: "<code>"}` strings that carry a clearer, action-specific
/// message than the generic status fallback. Keys map to `error.*` i18n entries
/// in all three bundles. Checked BEFORE the status buckets so e.g. a 422
/// `multi_shop_cart_not_supported` reads as a real explanation, not just
/// "Invalid input".
const Map<String, String> _codeMessages = {
  'product_not_found': 'error.product_unavailable',
  'seller_unavailable': 'error.seller_unavailable',
  'order_not_delivered': 'error.order_not_delivered',
  'already_reviewed': 'error.already_reviewed',
  'multi_shop_cart_not_supported': 'error.multi_shop_cart',
  'invalid_attachment_url': 'error.attachment_invalid',
  'wallet_suspended': 'error.wallet_suspended',
  'self_purchase_not_allowed': 'ai_designer.self_purchase_warning',
  // Checkout deep-links (POST /orders/{id}/pay/payme · /pay/click).
  'order_not_found': 'error.order_not_found',
  'order_not_payable': 'error.order_not_payable',
  'payments_unavailable': 'error.payments_unavailable',
  'wallet_topup_below_minimum': 'error.wallet_topup_below_minimum',
  'payment_already_pending': 'error.payment_already_pending',
};

/// Maps an [ApiError] (or any thrown object) to a localised, user-facing
/// message. Blocs/cubits should surface this instead of `e.toString()` so the
/// user never sees a raw English `DioException` / stack-flavoured string in a
/// uz/ru UI. Keys live under the `error.*` namespace in all three bundles.
String apiErrorMessage(Object error) {
  if (error is ApiError) {
    final mapped = _codeMessages[error.code];
    if (mapped != null) return tr(mapped);
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

/// Bridges the throw-world ([ApiError] / any thrown object) into the
/// Result-world [Failure] that `runCatching` returns as an `Err`. The
/// [Failure.message] is the SAME localised string [apiErrorMessage] produces,
/// so a repository moving from `throw` to `Result<T>` keeps identical error UX —
/// the call site reads `failure.message` instead of catching and re-mapping.
///
/// Pass it as `runCatching(body, onError: (e, _) => apiErrorToFailure(e))`; it's
/// the shared bridge for the command-repo migration (see the error-handling
/// boundary rule card).
Failure apiErrorToFailure(Object error) {
  final message = apiErrorMessage(error);
  if (error is ApiError) {
    if (error.isUnauthorized) {
      return AuthFailure(message: message, code: error.code);
    }
    if (error.status == 0 || error.code == 'network_error') {
      return NetworkFailure(message: message, code: error.code);
    }
    return ServerFailure(
      message: message,
      code: error.code,
      statusCode: error.status,
    );
  }
  if (error is TimeoutException) return NetworkFailure(message: message);
  return UnknownFailure(message: message);
}
