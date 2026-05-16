import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/auth/register_screen.dart';
import 'package:woody_app/core/i18n/i18n.dart';

/// ROADMAP B.5 — widget tests for the registration screen.
void main() {
  Widget harness() => const MaterialApp(home: RegisterScreen());

  testWidgets('renders the full-name / email / password / confirm fields',
      (tester) async {
    await tester.pumpWidget(harness());
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('submitting an empty form surfaces required-field errors',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text(tr('auth.validation_required')), findsWidgets);
  });

  testWidgets('a password / confirm mismatch is rejected', (tester) async {
    await tester.pumpWidget(harness());
    await tester.enterText(find.byType(TextFormField).at(0), 'Aziz Karimov');
    await tester.enterText(find.byType(TextFormField).at(1), 'aziz@woody.uz');
    await tester.enterText(find.byType(TextFormField).at(2), 'password-one');
    await tester.enterText(find.byType(TextFormField).at(3), 'password-two');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    // The confirm-password validator returns the password error on mismatch.
    expect(find.text(tr('auth.validation_password')), findsWidgets);
  });
}
