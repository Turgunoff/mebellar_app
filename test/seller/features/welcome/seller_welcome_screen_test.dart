import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/welcome/screens/seller_welcome_screen.dart';

void main() {
  Widget pump(VoidCallback onContinue) => MaterialApp(
        home: SellerWelcomeScreen(onContinue: onContinue),
      );

  testWidgets('renders the celebratory copy and the Boshlash CTA',
      (tester) async {
    await tester.pumpWidget(pump(() {}));
    // Let the entrance animation run without settling forever (the loop
    // controller repeats, so pumpAndSettle would time out).
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('Tabriklaymiz! 🎉'), findsOneWidget);
    expect(find.textContaining('muvaffaqiyatli tasdiqlandi'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Boshlash'), findsOneWidget);
  });

  testWidgets('invokes onContinue when Boshlash is tapped', (tester) async {
    var continued = 0;
    await tester.pumpWidget(pump(() => continued++));
    await tester.pump(const Duration(milliseconds: 1500));

    await tester.tap(find.widgetWithText(FilledButton, 'Boshlash'));
    expect(continued, 1);
  });
}
