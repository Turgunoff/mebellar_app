// Host-side driver for `flutter drive` runs of `integration_test/` targets.
// Persists every `binding.takeScreenshot(name)` the on-device test reports
// into `screenshots/<name>.png` (relative to the `flutter drive` cwd).

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('screenshots/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      // ignore: avoid_print
      print('Saved screenshot -> ${file.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
