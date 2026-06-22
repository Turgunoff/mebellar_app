import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/ar/ar_loading_overlay.dart';

void main() {
  Widget host(Widget overlay) =>
      MaterialApp(home: Scaffold(body: Stack(children: [overlay])));

  testWidgets('failed state shows the error + retry and fires onRetry', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      host(
        ArModelLoadingOverlay(
          ready: false,
          background: const Color(0xFFFFFFFF),
          failed: true,
          errorText: 'load failed',
          retryText: 'retry',
          onRetry: () => retried++,
        ),
      ),
    );

    expect(find.text('load failed'), findsOneWidget);
    expect(find.text('retry'), findsOneWidget);

    await tester.tap(find.text('retry'));
    expect(retried, 1);
  });

  testWidgets('loading (non-failed) state shows no retry affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ArModelLoadingOverlay(
          ready: false,
          background: Color(0xFFFFFFFF),
        ),
      ),
    );

    // The retry surface only exists in the failed state.
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('load failed'), findsNothing);
    // A single frame — the Lottie animation repeats, so never pumpAndSettle.
    await tester.pump();
  });
}
