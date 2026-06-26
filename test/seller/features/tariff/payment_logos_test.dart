import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the brand logos used by the tariff payment sheet's online-pay cards:
/// the asset must be declared, parse as valid SVG, and render without throwing.
void main() {
  testWidgets('Payme + Click SVG logos load and render without error', (
    tester,
  ) async {
    for (final asset in const [
      'assets/logo/payme.svg',
      'assets/logo/click.svg',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 84,
                height: 46,
                child: SvgPicture.asset(asset, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: asset);
      expect(find.byType(SvgPicture), findsOneWidget, reason: asset);
    }
  });
}
