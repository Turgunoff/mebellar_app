import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/auth/widgets/mode_chooser_bottom_sheet.dart';
import 'package:woody_app/config/app_mode.dart';

void main() {
  testWidgets('Mode chooser returns the picked mode', (tester) async {
    AppMode? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showModeChooserBottomSheet(ctx);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pumpAndSettle();

    expect(picked, AppMode.seller);
  });
}
