import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/theme/app_theme.dart';
import 'package:woody_app/customer/features/product_list/screens/buyer_ar_viewer_screen.dart';
import 'package:woody_app/shared/models/product_model.dart';

import '../../../../support/fake_webview_platform.dart';

// ModelViewer wraps a WebView platform view that has no plugin in the
// flutter_test harness, so its controller init asserts on a missing
// WebViewPlatform.instance. A no-op fake platform (installed in setUpAll) lets
// the widget mount; a single pump (no pumpAndSettle, which would hang on the
// indefinite proxy bind) is enough to read the mounted ModelViewer's config.
ProductModel _product({
  num? widthCm,
  num? heightCm,
  num? depthCm,
  String name = 'Krovat',
  String? usdzUrl,
  List<String> images = const [],
}) => ProductModel(
  id: 'p1',
  categoryId: 'cat-1',
  name: name,
  price: 1000000,
  images: images,
  stock: 5,
  createdAt: DateTime(2026, 1, 1),
  arModelUrl: 'https://example.com/model.glb',
  usdzUrl: usdzUrl,
  arStatus: 'approved',
  widthCm: widthCm,
  heightCm: heightCm,
  depthCm: depthCm,
);

Future<void> _pump(WidgetTester tester, ProductModel product) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: BuyerArViewerScreen(product: product),
    ),
  );
}

void main() {
  setUpAll(() {
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
    installFakeWebViewPlatform();
  });

  testWidgets('builds true-to-size with full dimensions', (tester) async {
    await _pump(
      tester,
      _product(widthCm: 180, heightCm: 90, depthCm: 200, name: 'Krovat'),
    );

    // Product name surfaces in the immersive top bar, the prominent AR launch
    // CTA is visible, and the save-to-gallery action sits in the top bar.
    expect(find.text('Krovat'), findsOneWidget);
    expect(find.text(tr('product.ar_place_cta')), findsOneWidget);
    expect(find.byIcon(Icons.save_alt), findsOneWidget);

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    // 1 scene unit = 1 metre, so cm/100 per axis.
    expect(viewer.scale, '1.8 0.9 2.0');
    // True scale is locked so buyers can't pinch-resize in AR.
    expect(viewer.arScale, ArScale.fixed);
    expect(viewer.ar, isTrue);
    expect(viewer.arPlacement, ArPlacement.floor);
    expect(viewer.environmentImage, 'neutral');
  });

  testWidgets('builds unscaled when dimensions are missing', (tester) async {
    await _pump(tester, _product(name: 'Stol'));

    expect(find.text('Stol'), findsOneWidget);

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    expect(viewer.scale, isNull);
    expect(viewer.arScale, isNull);
    // AR itself stays enabled even without a true-scale lock.
    expect(viewer.ar, isTrue);
  });

  testWidgets('builds unscaled when a dimension is zero', (tester) async {
    await _pump(
      tester,
      _product(widthCm: 120, heightCm: 0, depthCm: 60, name: 'Shkaf'),
    );

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    expect(viewer.scale, isNull);
    expect(viewer.arScale, isNull);
  });

  testWidgets('passes usdz through to iosSrc for iOS AR Quick Look', (tester) async {
    await _pump(tester, _product(usdzUrl: 'https://example.com/model.usdz'));

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    // glb drives src (Android/WebGL); usdz drives iosSrc (Quick Look).
    expect(viewer.src, 'https://example.com/model.glb');
    expect(viewer.iosSrc, 'https://example.com/model.usdz');
    // All three launchers offered so model-viewer can pick per platform.
    expect(viewer.arModes, const ['webxr', 'scene-viewer', 'quick-look']);
  });

  testWidgets('iosSrc is null when no usdz exists (glb-only, no crash)', (tester) async {
    await _pump(tester, _product());

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    expect(viewer.src, 'https://example.com/model.glb');
    // Null usdz → iosSrc null; model_viewer_plus omits the ios-src attribute and
    // iOS falls back to the in-page WebGL view. AR stays enabled.
    expect(viewer.iosSrc, isNull);
    expect(viewer.ar, isTrue);
  });

  testWidgets('uses the product photo as the loading poster', (tester) async {
    await _pump(
      tester,
      _product(images: const ['https://example.com/photo.jpg']),
    );

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    // The first product image fills the canvas (+ progress bar) while the .glb
    // downloads, instead of a blank white flash.
    expect(viewer.poster, 'https://example.com/photo.jpg');
  });

  testWidgets('poster is null when the product has no photo', (tester) async {
    await _pump(tester, _product());

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    expect(viewer.poster, isNull);
  });
}
