import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/auth/sheets/otp_step.dart';

Widget _host({
  required TextEditingController controller,
  required VoidCallback onSubmit,
}) => MaterialApp(
  home: Scaffold(
    body: OtpStep(
      destination: '+998 90 123 45 67',
      controller: controller,
      busy: false,
      onSubmit: onSubmit,
      remainingLabel: '00:30',
      canResend: false,
      onResend: () {},
      length: 5,
    ),
  ),
);

void main() {
  // OTP-02: the auto-submit must fire exactly once per unique completed code,
  // through a cancellable debounce timer, so autofill + manual paths and fast
  // edits can't double-submit.
  testWidgets('auto-submit fires once for a completed code and never repeats', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var submits = 0;

    await tester.pumpWidget(
      _host(controller: controller, onSubmit: () => submits++),
    );

    // Autofill drops the whole code in at once → trips the field listener.
    controller.text = '12345';
    await tester.pump(const Duration(milliseconds: 200));
    expect(submits, 1);

    // Settling further must not re-fire for the same value.
    await tester.pump(const Duration(milliseconds: 300));
    expect(submits, 1);

    // Editing back to the SAME full code is still one unique value → no resubmit.
    controller.text = '1234';
    await tester.pump(const Duration(milliseconds: 50));
    controller.text = '12345';
    await tester.pump(const Duration(milliseconds: 200));
    expect(submits, 1);
  });

  testWidgets(
    'a backspace-then-retype before the debounce elapses submits once',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var submits = 0;

      await tester.pumpWidget(
        _host(controller: controller, onSubmit: () => submits++),
      );

      controller.text = '11111'; // schedules a submit
      await tester.pump(
        const Duration(milliseconds: 50),
      ); // < 120ms — still pending
      controller.text = '1111'; // backspace cancels the pending submit
      await tester.pump(const Duration(milliseconds: 50));
      controller.text = '11112'; // a new full value
      await tester.pump(const Duration(milliseconds: 200));

      expect(submits, 1);
    },
  );
}
