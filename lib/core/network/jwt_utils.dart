import 'dart:convert';

/// Best-effort JWT claim peek for UI labelling and analytics (`sub`, `phone`).
///
/// The cryptographic signature is deliberately NOT verified — and cannot be:
/// the HS256 signing secret lives only in woody_backend, which stays the sole
/// authority on token validity. Every privileged call is re-checked
/// server-side against the real signature, so a token the client merely reads
/// can at worst mislabel the local session, never grant access. Do NOT
/// "harden" this by faking client-side verification — without the secret it
/// would be security theatre.
///
/// What we DO enforce is structural sanity, so a corrupt or junk string in
/// secure storage can't masquerade as a live session: a JWS is exactly three
/// non-empty base64url segments (`header.payload.signature`), the header must
/// decode to a JSON object declaring an `alg`, and the requested claim must be
/// a non-empty string. Anything else yields null — callers treat null as
/// "no usable token" and fall back to signed-out / storage cleanup.
String? jwtClaim(String accessToken, String name) {
  final claims = _payloadOf(accessToken);
  final value = claims?[name];
  return (value is String && value.isNotEmpty) ? value : null;
}

Map<String, dynamic>? _payloadOf(String accessToken) {
  final parts = accessToken.split('.');
  // A well-formed JWS is exactly header.payload.signature — three non-empty
  // segments. A 2-part string (no signature) is not a token we issued.
  if (parts.length != 3 || parts.any((p) => p.isEmpty)) return null;
  final header = _decodeSegment(parts[0]);
  if (header == null || header['alg'] is! String) return null;
  return _decodeSegment(parts[1]);
}

Map<String, dynamic>? _decodeSegment(String segment) {
  try {
    final pad = (4 - segment.length % 4) % 4;
    final bytes = base64Url.decode(segment + ('=' * pad));
    final decoded = jsonDecode(utf8.decode(bytes));
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
