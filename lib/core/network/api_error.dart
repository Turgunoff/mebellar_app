/// Typed error envelope for `api.woody.uz` responses.
///
/// FastAPI returns errors as `{"detail": "<code>"}` for application errors,
/// or `{"detail": [<validation_array>]}` for pydantic validation failures.
/// [code] is the machine-readable identifier callers should match on
/// (`invalid_code`, `otp_expired`, `rate_limited`, etc.) — UI layers map it
/// to a localized string via `core/i18n` / `auth_error_messages.dart`.
class ApiError implements Exception {
  ApiError({
    required this.status,
    required this.code,
    this.message,
    this.retryAfterSeconds,
  });

  final int status;
  final String code;
  final String? message;
  final int? retryAfterSeconds;

  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;
  bool get isRateLimited => status == 429;
  bool get isValidation => code == 'validation_error' || status == 422;

  @override
  String toString() =>
      'ApiError(status=$status, code=$code'
      '${message != null ? ', message=$message' : ''}'
      '${retryAfterSeconds != null ? ', retryAfter=$retryAfterSeconds' : ''})';
}
