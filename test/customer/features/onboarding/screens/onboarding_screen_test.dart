import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:woody_app/core/i18n/i18n.dart';
import 'package:woody_app/core/theme/app_theme.dart';
import 'package:woody_app/customer/features/onboarding/screens/onboarding_screen.dart';

import '../../../../support/fake_webview_platform.dart';

// OnboardingScreen page 1 mounts a ModelViewer (a webview_flutter platform
// view). The no-op fake platform (setUpAll) lets it mount; a single pump (no
// pumpAndSettle, which would hang on the indefinite proxy bind) is enough to
// read the mounted config. Skip / Get Started are NOT tapped — they call
// sl<AppSettings>(), which isn't registered in this lightweight widget test.
Future<void> _pump(WidgetTester tester) {
  return tester.pumpWidget(const _Harness());
}

class _Harness extends StatelessWidget {
  const _Harness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const OnboardingScreen(),
    );
  }
}

void main() {
  setUpAll(() {
    AppTranslations.setInstance(AppTranslations.forLocale(const Locale('uz')));
    installFakeWebViewPlatform();
  });

  testWidgets('page 1 renders a static, arc-scrubbed 3D model', (tester) async {
    await _pump(tester);
    await tester.pump();

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    expect(viewer.src, 'assets/models/onboarding_chair.glb');
    // Static: no auto-spin and no direct-touch controls — rotation comes only
    // from the arc, so a stray swipe can't tip, spin or zoom the chair.
    expect(viewer.ar, isFalse);
    expect(viewer.autoRotate, isFalse);
    expect(viewer.cameraControls, isFalse);
    expect(viewer.disableZoom, isTrue);
    // Pitch is pinned to 90deg (chair stays level); yaw seeds centred at 0.
    expect(viewer.cameraOrbit, '0deg 90deg auto');

    // The Material slider is gone, replaced by the custom curved arc control.
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const Key('onboarding_rotation_arc')), findsOneWidget);

    // The static-image poster is gone — a Flutter Lottie overlay covers the
    // load instead (model-viewer can't render Lottie natively).
    expect(viewer.poster, isNull);
  });

  testWidgets('page 1 shows the animated Lottie loader until the model loads', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump();

    // The model never fires `load` under the fake webview, so the loader stays
    // mounted (it only fades + unmounts on the real "ready" signal).
    expect(find.byType(LottieBuilder), findsOneWidget);
  });

  testWidgets('dragging the arc control updates without throwing', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump();

    final arc = find.byKey(const Key('onboarding_rotation_arc'));
    // A horizontal scrub must not crash or trip a layout error (no rebuild of
    // the model, so the framing can't jump).
    await tester.drag(arc, const Offset(80, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.drag(arc, const Offset(-160, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows Skip, animated page indicator and first-page copy', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump();

    expect(find.text(tr('common.skip')), findsOneWidget);
    expect(find.byType(SmoothPageIndicator), findsOneWidget);
    expect(find.text(tr('intro.page1_title')), findsOneWidget);
  });

  testWidgets('lays out without overflow on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(tr('common.skip')), findsOneWidget);
  });

  testWidgets('page 3 runs the infinite marquee without crashing', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump();

    // Swipe past page 2 to the marquee. Start the drags near the top edge so
    // they hit the PageView, not page 1's model / arc control. No
    // pumpAndSettle — the marquee ticker never settles.
    await tester.dragFrom(const Offset(400, 20), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.dragFrom(const Offset(400, 20), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 400));

    // Three tilted, auto-scrolling columns are live; the final CTA reads over
    // the gradient.
    expect(find.byType(ListView), findsNWidgets(3));
    expect(find.text(tr('intro.page3_title')), findsOneWidget);

    // Page 3 owns a centred "Get Started" CTA that pops in.
    expect(find.text(tr('intro.get_started')), findsOneWidget);

    // The generic bottom controls fade out + go inert on page 3 (Task 3): their
    // AnimatedOpacity — the one wrapping the page indicator — settles to 0.
    final footerOpacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(SmoothPageIndicator),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(footerOpacity.opacity, 0.0);

    // A few frames of the auto-scroll ticker must not throw (jumpTo on the
    // unbounded lists, missing grid assets degrading via errorBuilder, etc.).
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('generic Get Started CTA is absent on page 1', (tester) async {
    await _pump(tester);
    await tester.pump();

    // The final CTA lives inside page 3 now — page 1 shows only Skip + Next.
    expect(find.text(tr('intro.get_started')), findsNothing);
    expect(find.text(tr('common.skip')), findsOneWidget);
  });
}
