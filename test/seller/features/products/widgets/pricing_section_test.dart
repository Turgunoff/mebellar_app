import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/products/bloc/add_product_cubit.dart';
import 'package:woody_app/seller/features/products/widgets/product_form/pricing_section.dart';

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Future<void> pump(
    WidgetTester tester, {
    PriceCurrency currency = PriceCurrency.uzs,
    double? usdRate,
    int priceValue = 0,
    int uzsPrice = 0,
    int discountedUzsPrice = 0,
    int discountPercent = 0,
    ValueChanged<PriceCurrency>? onCurrencyChanged,
  }) async {
    // Narrow 320px phone — the worst case for the suffix toggle + the long
    // "≈ … UZS · 1 USD = … UZS" helper line. Ahem test glyphs are wider than
    // the real font, so passing here is stricter than production.
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PricingSection(
                priceController: controller,
                currency: currency,
                usdRate: usdRate,
                discountPercent: discountPercent,
                priceValue: priceValue,
                uzsPrice: uzsPrice,
                discountedUzsPrice: discountedUzsPrice,
                onPriceChanged: (_) {},
                onCurrencyChanged: onCurrencyChanged ?? (_) {},
                onDiscountSelected: (_) {},
                onCustomTapped: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('USD mode with a huge price renders without overflow at 320px', (
    tester,
  ) async {
    await pump(
      tester,
      currency: PriceCurrency.usd,
      usdRate: 12650.43,
      priceValue: 99999,
      uzsPrice: 1264930350,
      discountedUzsPrice: 885451245,
      discountPercent: 30,
    );

    // An overflowing RenderFlex/paint would surface as a test exception.
    expect(tester.takeException(), isNull);
    expect(find.text('UZS'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    // Live conversion helper + UZS-led summary with the USD echo.
    expect(find.textContaining('≈ 1 264 930 350 UZS'), findsOneWidget);
    expect(find.text('885 451 245 UZS'), findsOneWidget);
    expect(find.text('≈ 69 999 USD'), findsOneWidget);
  });

  testWidgets('tapping USD switches currency when the rate is loaded', (
    tester,
  ) async {
    final taps = <PriceCurrency>[];
    await pump(tester, usdRate: 12650.43, onCurrencyChanged: taps.add);

    await tester.tap(find.text('USD'));
    await tester.pump();

    expect(taps, [PriceCurrency.usd]);
  });

  testWidgets(
    'tapping the dimmed USD segment explains itself and still retries',
    (tester) async {
      final taps = <PriceCurrency>[];
      await pump(tester, usdRate: null, onCurrencyChanged: taps.add);

      await tester.tap(find.text('USD'));
      await tester.pump();

      // The snackbar tells the seller why nothing switched; the callback
      // still fires so the cubit can retry the rate fetch.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(taps, [PriceCurrency.usd]);
    },
  );

  testWidgets('UZS mode shows no conversion helper', (tester) async {
    await pump(
      tester,
      usdRate: 12650.43,
      priceValue: 500000,
      uzsPrice: 500000,
      discountedUzsPrice: 500000,
    );

    expect(find.textContaining('1 USD ='), findsNothing);
    expect(find.text('500 000 UZS'), findsOneWidget);
  });
}
