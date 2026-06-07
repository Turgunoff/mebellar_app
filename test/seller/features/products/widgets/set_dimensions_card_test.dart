import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/products/widgets/product_preview/spec_cards.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('SetDimensionsCard renders piece headers and measures', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SetDimensionsCard(
          groups: [
            SetDimensionGroup(
              piece: 'Krovat',
              measures: [
                ('Uzunligi', '214 sm'),
                ('Balandligi', '111 sm'),
                ('Kengligi', '197 sm'),
              ],
            ),
            SetDimensionGroup(
              piece: 'Shkaf',
              measures: [
                ('Kengligi', '220 sm'),
                ('Balandligi', '200 sm'),
                ('Chuqurligi', '47 sm'),
              ],
            ),
          ],
        ),
      ),
    );

    // Both piece headers and their values render.
    expect(find.text('Krovat'), findsOneWidget);
    expect(find.text('Shkaf'), findsOneWidget);
    expect(find.text('214 sm'), findsOneWidget);
    expect(find.text('47 sm'), findsOneWidget);
  });

  testWidgets('three measures fit side by side without overflow', (
    tester,
  ) async {
    // A narrow viewport stresses the side-by-side row — Expanded fields must
    // share the width rather than overflow.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const SetDimensionsCard(
          groups: [
            SetDimensionGroup(
              piece: 'Krovat',
              measures: [
                ('Uzunligi', '214 sm'),
                ('Balandligi', '111 sm'),
                ('Kengligi', '197 sm'),
              ],
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('empty groups render nothing', (tester) async {
    await tester.pumpWidget(_host(const SetDimensionsCard(groups: [])));
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.text("O'lchamlar (sm)"), findsNothing);
  });
}
