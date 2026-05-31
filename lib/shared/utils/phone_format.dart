/// Display-formats an Uzbek MSISDN for read-only UI.
///
/// Accepts either a full `+998XXXXXXXXX` (12 digits incl. country code) or a
/// bare 9-digit national number and renders `+998 XX XXX XX XX`. Anything that
/// doesn't match is returned untouched so foreign or malformed numbers still
/// surface verbatim rather than being mangled.
String formatUzPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  String? national;
  if (digits.length == 12 && digits.startsWith('998')) {
    national = digits.substring(3);
  } else if (digits.length == 9) {
    national = digits;
  }
  if (national == null) return raw;
  return '+998 ${national.substring(0, 2)} ${national.substring(2, 5)} '
      '${national.substring(5, 7)} ${national.substring(7, 9)}';
}
