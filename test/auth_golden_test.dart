import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/auth/login_screen.dart';
import 'package:woody_app/auth/register_screen.dart';

/// ROADMAP B.5 — golden tests for the auth screens.
///
/// Baseline PNGs live in `test/goldens/`. Regenerate them after an
/// intentional UI change with:
///
///   flutter test --update-goldens test/auth_golden_test.dart
///
/// Pixel output is renderer-dependent; if CI runs on a different OS than the
/// baseline was generated on, regenerate there.
void main() {
  Future<void> pumpSized(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump();
  }

  testWidgets('login screen matches its golden', (tester) async {
    await pumpSized(tester, const LoginScreen());
    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_screen.png'),
    );
  });

  testWidgets('register screen matches its golden', (tester) async {
    await pumpSized(tester, const RegisterScreen());
    await expectLater(
      find.byType(RegisterScreen),
      matchesGoldenFile('goldens/register_screen.png'),
    );
  });
}
