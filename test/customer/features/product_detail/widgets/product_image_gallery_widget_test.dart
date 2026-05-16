import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/product_detail/widgets/product_image_gallery.dart';

/// ROADMAP B.5 — widget tests for the product-detail image gallery, the
/// central visual component of the product detail screen. It is a pure
/// widget (no BLoC / DI), so it is tested directly.
void main() {
  Widget harness(List<String> images) => MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(images: images, heroTag: 'hero'),
        ),
      );

  testWidgets('shows a placeholder icon when there are no images',
      (tester) async {
    await tester.pumpWidget(harness(const []));
    await tester.pump();
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('renders a swipeable PageView for a non-empty image list',
      (tester) async {
    await tester.pumpWidget(harness(const [
      'https://example.com/1.jpg',
      'https://example.com/2.jpg',
      'https://example.com/3.jpg',
    ]));
    await tester.pump();
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('shows one page-indicator dot per image when there are several',
      (tester) async {
    await tester.pumpWidget(harness(const [
      'https://example.com/1.jpg',
      'https://example.com/2.jpg',
      'https://example.com/3.jpg',
    ]));
    await tester.pump();
    expect(find.byType(AnimatedContainer), findsNWidgets(3));
  });

  testWidgets('hides the page indicator for a single image', (tester) async {
    await tester.pumpWidget(harness(const ['https://example.com/only.jpg']));
    await tester.pump();
    expect(find.byType(AnimatedContainer), findsNothing);
  });
}
