import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/auth/login_screen.dart';
import 'package:woody_app/core/i18n/i18n.dart';

/// ROADMAP B.5 — widget tests for the login screen. `tr()` resolves against
/// the static `AppTranslations` singleton (uz bundle), so no localization
/// wrapper is needed — the screen renders real copy in the test environment.
void main() {
  Widget harness() => const MaterialApp(home: LoginScreen());

  testWidgets('renders the email + password fields and a submit button',
      (tester) async {
    await tester.pumpWidget(harness());
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('submitting an empty form surfaces validation errors',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    // The email field is empty -> the required-field validator fires.
    expect(find.text(tr('auth.validation_required')), findsWidgets);
  });

  testWidgets('an invalid email value is rejected by the field validator',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'supersecret');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text(tr('auth.validation_email')), findsOneWidget);
  });

  testWidgets('entering text populates the email field', (tester) async {
    await tester.pumpWidget(harness());
    await tester.enterText(find.byType(TextFormField).first, 'buyer@woody.uz');
    await tester.pump();
    expect(find.text('buyer@woody.uz'), findsOneWidget);
  });
}
