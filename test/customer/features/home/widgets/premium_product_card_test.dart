import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/home/widgets/premium/premium_product_card.dart';

/// Layout + interaction guards for the redesigned card. A single `pump()` is
/// used (not `pumpAndSettle`) so the off-screen network image never resolves —
/// these assert structure and overflow-safety, not pixels. A `RenderFlex`
/// overflow throws synchronously during layout, so it surfaces on the first
/// pump and `takeException()` catches it.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('fixed-aspect cell: discount + full price render, no overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 180,
          height: 268, // a realistic 2-column 0.66-ratio grid cell
          child: PremiumProductCard(
            imageUrl: 'https://example.com/x.jpg',
            name: 'SAFIA yotoq toʻplami klassik oq rangli garnitur',
            subtitle: 'Oq rangli klassik yotoq toʻplami',
            price: '6,292,203 UZS',
            oldPrice: '6,991,337 UZS',
            discountPercent: 10,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Both prices render in full — the FittedBox scales them down to fit the
    // freed-up width instead of clipping to "6,292,203 …".
    expect(find.text('6,292,203 UZS'), findsOneWidget);
    expect(
      find.text('6,991,337 UZS'),
      findsOneWidget,
    ); // strikethrough original
    expect(find.text('-10%'), findsOneWidget);
    // Quick-add was removed; tapping the card opens the detail screen instead.
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('masonry mode: renders, hides empty subtitle and shows no '
      'quick-add', (tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 180,
          child: PremiumProductCard(
            imageUrl: 'https://example.com/x.jpg',
            name: 'Manako yotoq toʻplami zamonaviy dizayndagi',
            price: '8,076,200 UZS',
            customImageHeight: 180,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('8,076,200 UZS'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.text('-10%'), findsNothing);
  });

  testWidgets('rating row renders only when a rating is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 180,
          child: PremiumProductCard(
            imageUrl: 'https://example.com/x.jpg',
            name: 'X',
            price: '1 UZS',
            customImageHeight: 120,
            rating: 4.8,
            reviewCount: 24,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('4.8 (24)'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('AR badge shows only when hasAr is true', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 180,
          child: PremiumProductCard(
            imageUrl: 'https://example.com/x.jpg',
            name: 'X',
            price: '1 UZS',
            customImageHeight: 120,
            hasAr: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.view_in_ar), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 180,
          child: PremiumProductCard(
            imageUrl: 'https://example.com/x.jpg',
            name: 'X',
            price: '1 UZS',
            customImageHeight: 120, // hasAr defaults to false
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.view_in_ar), findsNothing);
  });

  testWidgets('heart toggle and card tap fire their callbacks', (tester) async {
    var fav = 0;
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 180,
          child: PremiumProductCard(
            imageUrl: 'https://example.com/x.jpg',
            name: 'Tappable',
            price: '1 UZS',
            customImageHeight: 120,
            onFavoriteToggle: () => fav++,
            onTap: () => tapped++,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.favorite_border));
    expect(fav, 1);

    await tester.tap(find.text('Tappable'));
    expect(tapped, 1);
  });
}
