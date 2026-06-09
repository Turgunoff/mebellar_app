import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/network/jwt_utils.dart';

// Unpadded base64url segment, matching how real JWTs are encoded.
String _seg(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

String _jwt(
  Map<String, dynamic> header,
  Map<String, dynamic> payload, {
  String signature = 'sig',
}) =>
    '${_seg(header)}.${_seg(payload)}.$signature';

void main() {
  group('jwtClaim', () {
    test('reads string claims from a well-formed token', () {
      final token = _jwt(
        {'alg': 'HS256'},
        {'sub': 'user-1', 'phone': '+998901234567'},
      );
      expect(jwtClaim(token, 'sub'), 'user-1');
      expect(jwtClaim(token, 'phone'), '+998901234567');
    });

    test('returns null for an absent claim', () {
      final token = _jwt({'alg': 'HS256'}, {'sub': 'user-1'});
      expect(jwtClaim(token, 'role'), isNull);
    });

    test('returns null for a non-string claim', () {
      final token = _jwt({'alg': 'HS256'}, {'sub': 42});
      expect(jwtClaim(token, 'sub'), isNull);
    });

    test('returns null for an empty-string claim', () {
      final token = _jwt({'alg': 'HS256'}, {'sub': ''});
      expect(jwtClaim(token, 'sub'), isNull);
    });

    test('rejects a 2-segment token with no signature', () {
      final header = _seg({'alg': 'HS256'});
      final payload = _seg({'sub': 'user-1'});
      expect(jwtClaim('$header.$payload', 'sub'), isNull);
    });

    test('rejects a token with an empty segment', () {
      final payload = _seg({'sub': 'user-1'});
      expect(jwtClaim('.$payload.sig', 'sub'), isNull);
    });

    test('rejects a header that declares no algorithm', () {
      final token = _jwt({'typ': 'JWT'}, {'sub': 'user-1'});
      expect(jwtClaim(token, 'sub'), isNull);
    });

    test('rejects a payload that is not a JSON object', () {
      final header = _seg({'alg': 'HS256'});
      final payload =
          base64Url.encode(utf8.encode('"just-a-string"')).replaceAll('=', '');
      expect(jwtClaim('$header.$payload.sig', 'sub'), isNull);
    });

    test('returns null for garbage and empty input', () {
      expect(jwtClaim('garbage', 'sub'), isNull);
      expect(jwtClaim('', 'sub'), isNull);
      expect(jwtClaim('a.b.c', 'sub'), isNull);
    });
  });
}
