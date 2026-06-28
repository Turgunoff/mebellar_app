import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/theme/app_theme.dart';
import 'package:woody_app/customer/features/product_list/screens/buyer_ar_viewer_screen.dart';
import 'package:woody_app/shared/ar/glb_cache_manager.dart';
import 'package:woody_app/shared/models/ar_part.dart';
import 'package:woody_app/shared/models/product_model.dart';
import 'package:woody_app/shared/models/product_set.dart';
import 'package:woody_app/shared/repositories/woody_set_repository.dart';
import 'package:woody_app/shared/widgets/ar/product_3d_preview_view.dart';

import '../../../../support/fake_webview_platform.dart';

// ModelViewer wraps a WebView platform view that has no plugin in the
// flutter_test harness, so its controller init asserts on a missing
// WebViewPlatform.instance. A no-op fake platform (installed in setUpAll) lets
// the widget mount; pumping a few short frames (no pumpAndSettle, which would
// hang on the indefinite proxy bind) lets the cubit resolve the model source so
// the ModelViewer mounts, then reads its config.

/// A cache stand-in that always "misses" and resolves to the remote URL — so
/// the mounted ModelViewer's `src` is the network URL the assertions expect.
/// Mirrors GlbCacheService's real fallback when a file can't be cached.
class _UrlCache extends GlbCacheService {
  @override
  Future<String?> peek(String url) async => null;
  @override
  Future<String> resolve(String url) async => url;
}

class _MockSetRepo extends Mock implements WoodySetRepository {}

ProductModel _product({
  String id = 'p1',
  num? widthCm,
  num? heightCm,
  num? depthCm,
  String name = 'Krovat',
  String? usdzUrl,
  String? setId,
  List<String> images = const [],
  List<ArPart> arParts = const [],
}) => ProductModel(
  id: id,
  categoryId: 'cat-1',
  name: name,
  price: 1000000,
  images: images,
  stock: 5,
  createdAt: DateTime(2026, 1, 1),
  arModelUrl: 'https://example.com/model.glb',
  usdzUrl: usdzUrl,
  arStatus: 'approved',
  arParts: arParts,
  setId: setId,
  widthCm: widthCm,
  heightCm: heightCm,
  depthCm: depthCm,
);

Future<void> _pump(
  WidgetTester tester,
  ProductModel product, {
  WoodySetRepository? setRepository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: BuyerArViewerScreen(
        product: product,
        glbCache: _UrlCache(),
        setRepository: setRepository,
      ),
    ),
  );
  // Drain the cubit's source-resolution microtasks (downloading → rendering)
  // so the ModelViewer mounts. Plain pumps don't bind the model-viewer proxy
  // (real socket I/O), so no load watchdog timer is armed.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
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
    // Camera is pulled back (140% radius) with a tight FOV so tall pieces look
    // proportioned, not zoomed-in/stretched; manual zoom stays enabled.
    expect(viewer.cameraOrbit, '0deg 75deg 140%');
    expect(viewer.fieldOfView, '30deg');
    expect(viewer.cameraTarget, 'auto auto auto');
    expect(viewer.disableZoom, isFalse);
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

  testWidgets('renders the room backdrop behind a transparent canvas', (
    tester,
  ) async {
    await _pump(tester, _product());

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    // The canvas is transparent so the room photo behind shows through;
    // model_viewer_plus also forces the underlying WebView transparent.
    expect(viewer.backgroundColor, Colors.transparent);
    // ...and relatedCss kills the default opaque-white poster + host page that
    // would otherwise cover the backdrop while the .glb streams in (the "solid
    // white block" bug). All three must read transparent.
    final css = viewer.relatedCss ?? '';
    expect(css, contains('--poster-color:transparent'));
    expect(css, contains('model-viewer{background-color:transparent'));
    expect(css, contains('html,body{background-color:transparent'));

    // The room-context backdrop asset is mounted (as an Image.asset) behind
    // the model — the sole visible backdrop under the transparent Scaffold.
    final backdropAssets = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<AssetImage>()
        .map((a) => a.assetName)
        .toList();
    expect(backdropAssets, contains('assets/images/viewer_3d_bg.webp'));
  });

  testWidgets('no part selector for a standalone product', (tester) async {
    await _pump(tester, _product(name: 'Stol'));
    // Single product → the name shows once (top-bar title), with no second
    // selector chip echoing it.
    expect(find.text('Stol'), findsOneWidget);
  });

  testWidgets('multi-part product (garnitur) shows the part selector', (
    tester,
  ) async {
    // A single listing carrying its own bed/wardrobe parts (product_ar_parts,
    // not a product_set). The primary part shares the product's model URL so it
    // stays selected without a duplicate chip.
    await _pump(
      tester,
      _product(
        id: 'bed',
        name: 'Krovat',
        arParts: const [
          ArPart(
            id: 'bed',
            label: 'Krovat',
            arModelUrl: 'https://example.com/model.glb',
          ),
          ArPart(id: 'wd', label: 'Shkaf', arModelUrl: 'https://cdn/wd.glb'),
        ],
      ),
    );

    // The active 'Krovat' part shows twice — top-bar title + the model switcher
    // pill; sibling parts live behind the switcher sheet (not on screen yet).
    // hasMultipleParts is true here — the gate that routes the AR CTA to the
    // native multi-object scene instead of single-model OS AR.
    expect(find.byType(ArModelSwitcherButton), findsOneWidget);
    expect(find.text('Krovat'), findsNWidgets(2));
    expect(find.text('Shkaf'), findsNothing);
  });

  testWidgets('shows a part selector and toggles models for a set', (
    tester,
  ) async {
    final repo = _MockSetRepo();
    when(() => repo.fetchSet(any())).thenAnswer(
      (_) async => SetDetail(
        info: const ProductSet(
          id: 's1',
          shopId: 'shop',
          sellerId: 'seller',
          name: 'Yotoqxona',
        ),
        items: [
          _product(id: 'bed', name: 'Krovat', setId: 's1'),
          _product(id: 'wardrobe', name: 'Shkaf', setId: 's1'),
          _product(id: 'mirror', name: 'Tryumo', setId: 's1'),
        ],
      ),
    );

    await _pump(
      tester,
      _product(id: 'bed', name: 'Krovat', setId: 's1'),
      setRepository: repo,
    );

    // The opened product (Krovat) is the active part: its name shows twice
    // (top-bar title + switcher pill); siblings are hidden until the switcher
    // sheet opens.
    expect(find.text('Krovat'), findsNWidgets(2));
    expect(find.text('Shkaf'), findsNothing);
    expect(find.text('Tryumo'), findsNothing);

    // Open the switcher → every part appears as a row.
    await tester.tap(find.byType(ArModelSwitcherButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Shkaf'), findsOneWidget);
    expect(find.text('Tryumo'), findsOneWidget);

    // Pick Shkaf → the sheet closes and the active model (+ title) switches.
    await tester.tap(find.text('Shkaf'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Shkaf'), findsNWidgets(2));
    expect(find.text('Krovat'), findsNothing);
  });
}
