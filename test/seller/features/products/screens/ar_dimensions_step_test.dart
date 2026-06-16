import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/products/screens/ar_scan_camera_screen.dart';

void main() {
  ({int h, int w, int l})? submitted;

  Widget harness({bool submitting = false, String? error}) {
    submitted = null;
    return MaterialApp(
      home: Scaffold(
        body: ArDimensionsStep(
          submitting: submitting,
          error: error,
          onClose: () {},
          onSubmit: ({
            required int heightCm,
            required int widthCm,
            required int lengthCm,
          }) {
            submitted = (h: heightCm, w: widthCm, l: lengthCm);
          },
        ),
      ),
    );
  }

  Finder uploadButton() => find.widgetWithText(FilledButton, 'Yuklash');

  testWidgets('Yuklash is disabled until all three dims are positive',
      (tester) async {
    await tester.pumpWidget(harness());

    expect(tester.widget<FilledButton>(uploadButton()).onPressed, isNull);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '200'); // Bo'yi
    await tester.enterText(fields.at(1), '90'); // Eni
    await tester.pump();
    // Still missing the third field.
    expect(tester.widget<FilledButton>(uploadButton()).onPressed, isNull);

    await tester.enterText(fields.at(2), '210'); // Uzunligi
    await tester.pump();
    expect(tester.widget<FilledButton>(uploadButton()).onPressed, isNotNull);
  });

  testWidgets('zero is rejected as a dimension', (tester) async {
    await tester.pumpWidget(harness());
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '0');
    await tester.enterText(fields.at(1), '90');
    await tester.enterText(fields.at(2), '210');
    await tester.pump();
    expect(tester.widget<FilledButton>(uploadButton()).onPressed, isNull);
  });

  testWidgets('submit forwards the three parsed dimensions', (tester) async {
    await tester.pumpWidget(harness());
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '200');
    await tester.enterText(fields.at(1), '90');
    await tester.enterText(fields.at(2), '210');
    await tester.pump();

    await tester.tap(uploadButton());
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted!.h, 200);
    expect(submitted!.w, 90);
    expect(submitted!.l, 210);
  });

  testWidgets('while submitting the button is disabled even when valid',
      (tester) async {
    await tester.pumpWidget(harness(submitting: true));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '200');
    await tester.enterText(fields.at(1), '90');
    await tester.enterText(fields.at(2), '210');
    await tester.pump();
    expect(tester.widget<FilledButton>(uploadButton()).onPressed, isNull);
  });
}
