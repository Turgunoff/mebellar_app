import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/ar/ar_loading_overlay.dart';

/// Every keyframe time in a Lottie document, however deeply nested.
Set<num> _keyframeTimes(Object? node, [Set<num>? found]) {
  final times = found ?? <num>{};
  if (node is Map) {
    final t = node['t'];
    if (t is num &&
        node.keys.any((k) => const ['s', 'e', 'i', 'h'].contains(k))) {
      times.add(t);
    }
    for (final v in node.values) {
      _keyframeTimes(v, times);
    }
  } else if (node is List) {
    for (final v in node) {
      _keyframeTimes(v, times);
    }
  }
  return times;
}

void main() {
  Widget host(Widget overlay) => MaterialApp(
    home: Scaffold(body: Stack(children: [overlay])),
  );

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

  // Guards the `126 / 150` trim in `_SearchLoopLottie`: the animation's last
  // keyframe is well before its declared out-point, and playing the dead tail
  // is what made the loader look frozen. Re-exporting the asset changes these
  // numbers — this test says so instead of the loop silently stuttering again.
  test('search_lottie.json still holds still after frame 126 of 150', () {
    final doc =
        jsonDecode(File('assets/lottie/search_lottie.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(doc['op'], 150, reason: 'composition out-point');
    expect(_keyframeTimes(doc).reduce((a, b) => a > b ? a : b), 126);
  });
}
