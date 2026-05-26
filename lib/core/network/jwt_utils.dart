import 'dart:convert';

/// Best-effort JWT claim peek. Signature is intentionally NOT verified — the
/// server is the authority on token validity; this is only used to surface
/// the user id (`sub` claim) for UI labelling and analytics.
String? jwtClaim(String accessToken, String name) {
  final parts = accessToken.split('.');
  if (parts.length < 2) return null;
  try {
    var payload = parts[1];
    final pad = (4 - payload.length % 4) % 4;
    payload = payload + ('=' * pad);
    final bytes = base64Url.decode(payload);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map && decoded[name] is String) {
      return decoded[name] as String;
    }
    return null;
  } catch (_) {
    return null;
  }
}
