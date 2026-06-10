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

  group('resolveUpdateAction', () {
    test('no Play update → none, even when below min_version', () {
      expect(
        resolveUpdateAction(
          playUpdateAvailable: false,
          immediateAllowed: true,
          flexibleAllowed: true,
          installedVersion: '1.0.0',
          minVersion: '1.0.5',
        ),
        AppUpdateAction.none,
      );
    });

    test('below min_version → immediate', () {
      expect(
        resolveUpdateAction(
          playUpdateAvailable: true,
          immediateAllowed: true,
          flexibleAllowed: true,
          installedVersion: '1.0.4',
          minVersion: '1.0.5',
        ),
        AppUpdateAction.immediate,
      );
    });

    test('forced but immediate not allowed → falls back to flexible', () {
      expect(
        resolveUpdateAction(
          playUpdateAvailable: true,
          immediateAllowed: false,
          flexibleAllowed: true,
          installedVersion: '1.0.4',
          minVersion: '1.0.5',
        ),
        AppUpdateAction.flexible,
      );
    });

    test('at or above min_version → soft flexible prompt', () {
      expect(
        resolveUpdateAction(
          playUpdateAvailable: true,
          immediateAllowed: true,
          flexibleAllowed: true,
          installedVersion: '1.0.5',
          minVersion: '1.0.5',
        ),
        AppUpdateAction.flexible,
      );
    });

    test('no min_version configured → soft flexible prompt', () {
      expect(
        resolveUpdateAction(
          playUpdateAvailable: true,
          immediateAllowed: true,
          flexibleAllowed: true,
          installedVersion: '1.0.9',
          minVersion: null,
        ),
        AppUpdateAction.flexible,
      );
    });

    test('soft case never escalates to the blocking immediate flow', () {
      expect(
        resolveUpdateAction(
          playUpdateAvailable: true,
          immediateAllowed: true,
          flexibleAllowed: false,
          installedVersion: '1.0.9',
          minVersion: null,
        ),
        AppUpdateAction.none,
      );
    });

    test('forced with neither flow allowed → none', () {
      expect(
        resolveUpdateAction(
          playUpdateAvailable: true,
          immediateAllowed: false,
          flexibleAllowed: false,
          installedVersion: '1.0.0',
          minVersion: '1.0.5',
        ),
        AppUpdateAction.none,
      );
    });
  });
}
