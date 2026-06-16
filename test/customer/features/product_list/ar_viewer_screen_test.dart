import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/theme/app_theme.dart';
import 'package:woody_app/customer/features/product_list/screens/ar_viewer_screen.dart';

import '../../../support/fake_webview_platform.dart';

// ModelViewer wraps a WebView platform view that has no plugin in the
// flutter_test harness, so its controller init asserts on a missing
// WebViewPlatform.instance. A no-op fake platform (installed in setUpAll) lets
// the widget mount; a single pump (no pumpAndSettle, which would hang on the
// indefinite proxy bind) is enough to read the mounted ModelViewer's config.
Future<void> _pump(WidgetTester tester, ArViewerScreen screen) {
  return tester.pumpWidget(
    MaterialApp(theme: AppTheme.lightTheme, home: screen),
  );
}

void main() {
  setUpAll(() {
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
    installFakeWebViewPlatform();
  });

  testWidgets('builds with full dimensions and scales the model', (
    tester,
  ) async {
    await _pump(
      tester,
      const ArViewerScreen(
        modelUrl: 'https://example.com/model.glb',
        productName: 'Krovat',
        widthCm: 180,
        heightCm: 90,
        depthCm: 200,
      ),
    );

    expect(find.text(tr('product.ar_viewer_title')), findsOneWidget);

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    // 1 scene unit = 1 metre, so cm/100 per axis.
    expect(viewer.scale, '1.8 0.9 2.0');
    // True scale is locked so buyers can't pinch-resize in AR.
    expect(viewer.arScale, ArScale.fixed);
  });

  testWidgets('builds unscaled when dimensions are missing', (tester) async {
    await _pump(
      tester,
      const ArViewerScreen(
        modelUrl: 'https://example.com/model.glb',
        productName: 'Stol',
      ),
    );

    expect(find.text(tr('product.ar_viewer_title')), findsOneWidget);

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    expect(viewer.scale, isNull);
    expect(viewer.arScale, isNull);
  });

  testWidgets('builds unscaled when a dimension is zero', (tester) async {
    await _pump(
      tester,
      const ArViewerScreen(
        modelUrl: 'https://example.com/model.glb',
        productName: 'Shkaf',
        widthCm: 120,
        heightCm: 0,
        depthCm: 60,
      ),
    );

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    expect(viewer.scale, isNull);
    expect(viewer.arScale, isNull);
  });
}
