import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/core/updates/app_update_service.dart';

void main() {
  group('compareVersions', () {
    test('equal versions compare as 0', () {
      expect(compareVersions('1.0.9', '1.0.9'), 0);
      expect(compareVersions('1.0', '1.0.0'), 0);
    });

    test('orders numerically, not lexically', () {
      expect(compareVersions('1.0.9', '1.0.10'), lessThan(0));
      expect(compareVersions('1.0.10', '1.0.9'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('ignores a +buildNumber suffix', () {
      expect(compareVersions('1.0.9+9', '1.0.9'), 0);
      expect(compareVersions('1.0.9+9', '1.0.10+10'), lessThan(0));
    });

    test('missing segments read as 0', () {
      expect(compareVersions('1.1', '1.0.5'), greaterThan(0));
      expect(compareVersions('1', '1.0.0'), 0);
    });

    test('malformed segments read as 0 instead of throwing', () {
      expect(compareVersions('1.x.9', '1.0.9'), 0);
      expect(compareVersions('', '0.0.0'), 0);
    });
  });

  group('isUpdateRequired', () {
    test('installed below min → forced', () {
      expect(isUpdateRequired('1.0.4', '1.0.5'), isTrue);
      expect(isUpdateRequired('1.0.9', '1.1.0'), isTrue);
      // numeric, not lexical: 1.2.0 < 1.10.0
      expect(isUpdateRequired('1.2.0', '1.10.0'), isTrue);
    });

    test('installed at or above min → not forced', () {
      expect(isUpdateRequired('1.0.5', '1.0.5'), isFalse);
      expect(isUpdateRequired('1.1.0', '1.0.9'), isFalse);
      expect(isUpdateRequired('2.0.0', '1.9.9'), isFalse);
    });

    test('ignores a +buildNumber suffix on the installed version', () {
      expect(isUpdateRequired('1.0.5+42', '1.0.5'), isFalse);
      expect(isUpdateRequired('1.0.4+42', '1.0.5'), isTrue);
    });
  });
}
