import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/products/widgets/ar_not_approved_card.dart';

void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: ArNotApprovedCard())),
  );

  testWidgets('shows the approval-required message and a lock icon', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(ArNotApprovedCard.message), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('3D model (AR)'), findsOneWidget);
  });

  testWidgets('exposes no scan / buy actions (fully locked)', (tester) async {
    await pump(tester);

    // The locked card is presentational only — no FilledButton (scan / buy) and
    // no tappable InkWell affordance.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });
}
