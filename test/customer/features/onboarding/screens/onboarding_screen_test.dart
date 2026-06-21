import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('page 1 spins a hands-off 3D model', (tester) async {
    await _pump(tester);
    await tester.pump();

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    expect(viewer.src, 'assets/models/onboarding_chair.glb');
    // Elegant idle spin with no user disruption.
    expect(viewer.ar, isFalse);
    expect(viewer.autoRotate, isTrue);
    expect(viewer.cameraControls, isFalse);
    expect(viewer.disableZoom, isTrue);
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
}
