import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/config/remote_config.dart';

void main() {
  group('RemoteConfig.parseMinVersions', () {
    test('reads both platforms from the canonical payload', () {
      final parsed = RemoteConfig.parseMinVersions({
        'android': {'min_version': '1.0.3', 'latest_version': '1.0.9'},
        'ios': {'min_version': '2.0.0', 'latest_version': '2.1.0'},
      });
      expect(parsed.androidMin, '1.0.3');
      expect(parsed.iosMin, '2.0.0');
    });

    test('tolerates a payload missing one platform', () {
      final parsed = RemoteConfig.parseMinVersions({
        'android': {'min_version': '1.0.3'},
      });
      expect(parsed.androidMin, '1.0.3');
      expect(parsed.iosMin, isNull);
    });

    test('empty and whitespace-only strings read as null', () {
      final parsed = RemoteConfig.parseMinVersions({
        'android': {'min_version': ''},
        'ios': {'min_version': '   '},
      });
      expect(parsed.androidMin, isNull);
      expect(parsed.iosMin, isNull);
    });

    test('non-map payloads read as null instead of throwing', () {
      expect(RemoteConfig.parseMinVersions(null).androidMin, isNull);
      expect(RemoteConfig.parseMinVersions('1.0.9').androidMin, isNull);
      expect(
        RemoteConfig.parseMinVersions(<String, dynamic>{}).androidMin,
        isNull,
      );
      expect(
        RemoteConfig.parseMinVersions({'android': '1.0.9'}).androidMin,
        isNull,
      );
    });
  });
}
