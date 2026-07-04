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

  group('ArActivationOutcome', () {
    test('documents launched vs unsupported', () {
      expect(ArActivationOutcome.launched.name, 'launched');
      expect(ArActivationOutcome.unsupported.name, 'unsupported');
    });
  });
}
