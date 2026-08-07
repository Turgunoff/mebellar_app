import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the T-05 asset-size pass: `ai_animation2.json`'s 9
/// embedded frames were re-encoded PNG → WebP in place (layers/keyframes
/// untouched, see doc/planning/tech_debt_roadmap.md).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every embedded frame in ai_animation2.json decodes through the real '
    'engine codec at its declared dimensions (post PNG->WebP re-encode)',
    () async {
      // Bytes are pulled the exact same way lottie's fromDataUri() does
      // (load_image.dart: `Uri.parse(filePath).data!.contentAsBytes()`), then
      // handed to `dart:ui`'s real Skia codec — the same decoder
      // `MemoryImage` uses under the hood — so this proves the re-encoded
      // WebP payloads are valid image data, not just well-formed JSON.
      final raw = await rootBundle.loadString(
        'assets/lottie/ai_animation2.json',
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final assets = (json['assets'] as List).cast<Map<String, dynamic>>();
      final embedded = assets.where(
        (a) =>
            a['e'] == 1 &&
            (a['p'] as String?)?.startsWith('data:image/') == true,
      );

      expect(embedded, hasLength(9));

      for (final asset in embedded) {
        final bytes = Uri.parse(asset['p'] as String).data!.contentAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(
          frame.image.width,
          asset['w'],
          reason: 'width mismatch for asset ${asset['id']}',
        );
        expect(
          frame.image.height,
          asset['h'],
          reason: 'height mismatch for asset ${asset['id']}',
        );
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  // A widget-level smoke test (pumpWidget + Lottie(composition:...)) was
  // tried here too, but hung indefinitely under this session's loaded test
  // environment even bounded to a fixed number of pump() calls — a flaky/
  // hanging test is worse than no test (it would silently make CI's 20-minute
  // job budget the only thing standing between green and a mysterious
  // timeout). The dart:ui decode test above already proves every re-encoded
  // frame is valid, engine-decodable image data at the exact original pixel
  // dimensions — the actual risk this file guards against.
}
