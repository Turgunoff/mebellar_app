import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/home/widgets/premium/premium_product_list_card.dart';

/// Structure + overflow guards for the list-view card. A single `pump()` keeps
/// the off-screen network image unresolved; a `RenderFlex` overflow throws
/// during layout, so `takeException()` catches it on the first frame.
void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('image-left layout renders name + full price, no overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 360,
          child: PremiumProductListCard(
            imageUrl: 'https://example.com/x.jpg',
            name: "SAFIA yotoq to'plami (krovat + shkaf + tumba)",
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
    expect(find.text('6,292,203 UZS'), findsOneWidget);
    expect(find.text('6,991,337 UZS'), findsOneWidget);
    expect(find.text('-10%'), findsOneWidget);
    // No quick-add on the list card either — tap routes to detail.
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('survives a 1.3x OS text scale without overflow', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: const SizedBox(
              width: 360,
              child: PremiumProductListCard(
                imageUrl: 'https://example.com/x.jpg',
                name: "SAFIA yotoq to'plami (krovat + shkaf + tumba + oyna)",
                subtitle: 'Oq rangli klassik yotoq toʻplami zamonaviy',
                price: '6,292,203 UZS',
                oldPrice: '6,991,337 UZS',
                discountPercent: 10,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Enlarged system fonts must grow the card, not overflow its box.
    expect(tester.takeException(), isNull);
  });

  testWidgets('heart toggle and card tap fire their callbacks', (tester) async {
    var fav = 0;
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 360,
          child: PremiumProductListCard(
            imageUrl: 'https://example.com/x.jpg',
            name: 'Tappable',
            price: '1 UZS',
            onTap: () => tapped++,
            onFavoriteToggle: () => fav++,
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
