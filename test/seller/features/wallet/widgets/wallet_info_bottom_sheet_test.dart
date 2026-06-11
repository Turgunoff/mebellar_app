import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/wallet/widgets/wallet_info_bottom_sheet.dart';

Widget _host() => MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3949AB)),
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () => showWalletInfoBottomSheet(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('renders the title and all three explainer items', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Hamyon qanday ishlaydi?'), findsOneWidget);
    expect(find.text('Vazifasi'), findsOneWidget);
    expect(find.text('Avtomatik yechish'), findsOneWidget);
    expect(find.text('Qarzdorlik va muzlatish'), findsOneWidget);

    // Each item carries its leading glyph.
    expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    expect(find.byIcon(Icons.autorenew), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('the close button dismisses the sheet', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(WalletInfoBottomSheet), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(WalletInfoBottomSheet), findsNothing);
  });
}
