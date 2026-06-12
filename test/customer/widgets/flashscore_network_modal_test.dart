import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/widgets/flashscore_network_modal.dart';

void main() {
  Widget harness({required bool retrying, required VoidCallback onRetry}) =>
      MaterialApp(
        home: Scaffold(
          body: FlashscoreNetworkModal(retrying: retrying, onRetry: onRetry),
        ),
      );

  testWidgets('renders the no-connection copy and a Retry label at rest', (
    tester,
  ) async {
    await tester.pumpWidget(harness(retrying: false, onRetry: () {}));

    expect(find.text("Internetga ulanib bo'lmadi"), findsOneWidget);
    expect(find.text('Qayta urinish'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tapping Retry fires onRetry once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(retrying: false, onRetry: () => taps++));

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('while retrying: shows a spinner and disables the button', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(harness(retrying: true, onRetry: () => taps++));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Qayta urinish'), findsNothing);

    // onPressed is null while retrying — the tap is a no-op.
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });
}
