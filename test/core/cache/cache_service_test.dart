import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:woody_app/core/cache/cache_service.dart';

/// Stands in for the real path_provider plugin, which is not registered in the
/// `flutter_test` harness. [DefaultCacheService] calls the top-level
/// `getTemporaryDirectory()` rather than taking an injected seam, so swapping
/// the *platform* is the only way to drive it from a test.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider({this.temporaryPath, this.throws = false});

  final String? temporaryPath;

  /// Reproduces the failure mode the `await` in `sizeBytes()` exists for.
  final bool throws;

  @override
  Future<String?> getTemporaryPath() async {
    if (throws) throw Exception('no temp dir on this platform');
    return temporaryPath;
  }
}

void main() {
  late PathProviderPlatform original;

  setUp(() => original = PathProviderPlatform.instance);
  tearDown(() => PathProviderPlatform.instance = original);

  test('sizeBytes sums the files in the temp directory', () async {
    final dir = await Directory.systemTemp.createTemp('woody_cache_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/a.bin').writeAsBytesSync(List.filled(128, 0));
    Directory('${dir.path}/nested').createSync();
    File('${dir.path}/nested/b.bin').writeAsBytesSync(List.filled(64, 0));

    PathProviderPlatform.instance = _FakePathProvider(temporaryPath: dir.path);

    expect(await const DefaultCacheService().sizeBytes(), 192);
  });

  test('sizeBytes returns 0 when the temp directory does not exist', () async {
    PathProviderPlatform.instance = _FakePathProvider(
      temporaryPath: '${Directory.systemTemp.path}/woody_does_not_exist_xyz',
    );

    expect(await const DefaultCacheService().sizeBytes(), 0);
  });

  test(
    'sizeBytes returns 0 instead of throwing when the temp dir lookup fails',
    () async {
      // This is the exact regression the `await` before `_directorySize` was
      // added for: returning the future unawaited let it complete OUTSIDE the
      // try, so this error escaped to the caller instead of degrading to 0.
      PathProviderPlatform.instance = _FakePathProvider(throws: true);

      expect(await const DefaultCacheService().sizeBytes(), 0);
    },
  );
}
