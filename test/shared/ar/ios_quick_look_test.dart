import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/ar/ar_activation.dart';
import 'package:woody_app/shared/ar/glb_cache_manager.dart';
import 'package:woody_app/shared/ar/ios_quick_look.dart';

class _FakeCache extends GlbCacheService {
  _FakeCache(this.path);

  final String path;

  @override
  Future<String> resolve(String url) async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IosQuickLookLauncher.localPathForTest', () {
    test('parses file uri', () async {
      final path = await IosQuickLookLauncher.localPathForTest(
        'file:///tmp/demo.usdz',
      );
      expect(path, '/tmp/demo.usdz');
    });

    test('caches remote usdz to a local path', () async {
      final path = await IosQuickLookLauncher.localPathForTest(
        'https://cdn.woody.uz/model.usdz',
        cache: _FakeCache('file:///var/mobile/model.usdz'),
      );
      expect(path, '/var/mobile/model.usdz');
    });

    test('returns null when cache misses', () async {
      final path = await IosQuickLookLauncher.localPathForTest(
        'https://cdn.woody.uz/model.usdz',
        cache: _FakeCache('https://cdn.woody.uz/model.usdz'),
      );
      expect(path, isNull);
    });
  });

  group('IosQuickLookLauncher.ensureUsdzExtensionForTest', () {
    test('passes through an existing .usdz path', () async {
      final dir = await Directory.systemTemp.createTemp('woody_usdz_test');
      addTearDown(() => dir.delete(recursive: true));

      final usdz = File('${dir.path}/model.usdz')..writeAsBytesSync([1, 2, 3]);
      final out = await IosQuickLookLauncher.ensureUsdzExtensionForTest(
        usdz.path,
      );
      expect(out, usdz.path);
    });

    test('copies a .vnd cache file to .usdz for Quick Look', () async {
      final dir = await Directory.systemTemp.createTemp('woody_usdz_test');
      addTearDown(() => dir.delete(recursive: true));

      final vnd = File('${dir.path}/cache-id.vnd')..writeAsBytesSync([4, 5, 6]);
      final out = await IosQuickLookLauncher.ensureUsdzExtensionForTest(
        vnd.path,
      );

      expect(out, isNotNull);
      expect(out!.toLowerCase(), endsWith('.usdz'));
      expect(File(out).readAsBytesSync(), [4, 5, 6]);
    });

    test('returns null when the source file is missing', () async {
      final out = await IosQuickLookLauncher.ensureUsdzExtensionForTest(
        '/tmp/does-not-exist-${DateTime.now().microsecondsSinceEpoch}.vnd',
      );
      expect(out, isNull);
    });
  });

  group('ArActivationOutcome', () {
    test('documents launched vs unsupported', () {
      expect(ArActivationOutcome.launched.name, 'launched');
      expect(ArActivationOutcome.unsupported.name, 'unsupported');
    });
  });
}
