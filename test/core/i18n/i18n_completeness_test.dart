import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/i18n/translations/_missing_keys_check.dart';

/// ROADMAP B.8 — guards translation completeness in CI. The `uz` bundle is
/// the source of truth; `ru` and `en` must cover every `uz` key or a
/// locale-switched user sees raw `key.path` strings.
void main() {
  group('translation completeness', () {
    final audit = auditTranslations();

    test('ru bundle covers every uz key', () {
      expect(
        audit.missingInRu,
        isEmpty,
        reason: 'ru is missing keys present in uz:\n${audit.report()}',
      );
    });

    test('en bundle covers every uz key', () {
      expect(
        audit.missingInEn,
        isEmpty,
        reason: 'en is missing keys present in uz:\n${audit.report()}',
      );
    });
  });
}
