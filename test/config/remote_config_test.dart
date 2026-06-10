import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/config/remote_config.dart';

void main() {
  group('RemoteConfig.parseAndroidVersions', () {
    test('reads both fields from the canonical payload', () {
      final parsed = RemoteConfig.parseAndroidVersions({
        'android': {'min_version': '1.0.3', 'latest_version': '1.0.9'},
      });
      expect(parsed.min, '1.0.3');
      expect(parsed.latest, '1.0.9');
    });

    test('tolerates a partial payload', () {
      final parsed = RemoteConfig.parseAndroidVersions({
        'android': {'min_version': '1.0.3'},
      });
      expect(parsed.min, '1.0.3');
      expect(parsed.latest, isNull);
    });

    test('empty and whitespace-only strings read as null', () {
      final parsed = RemoteConfig.parseAndroidVersions({
        'android': {'min_version': '', 'latest_version': '   '},
      });
      expect(parsed.min, isNull);
      expect(parsed.latest, isNull);
    });

    test('non-map payloads read as null instead of throwing', () {
      expect(RemoteConfig.parseAndroidVersions(null).min, isNull);
      expect(RemoteConfig.parseAndroidVersions('1.0.9').min, isNull);
      expect(
        RemoteConfig.parseAndroidVersions(<String, dynamic>{}).min,
        isNull,
      );
      expect(
        RemoteConfig.parseAndroidVersions({'android': '1.0.9'}).min,
        isNull,
      );
    });
  });
}
