import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/customer/features/product_detail/widgets/product_image_gallery.dart';

/// ROADMAP B.5 — golden test for the product-detail image gallery.
///
/// Regenerate the baseline:
///   flutter test --update-goldens test/customer/features/product_detail/widgets/product_gallery_golden_test.dart
void main() {
  // The gallery's empty/placeholder state is used as the golden: a populated
  // gallery would mount `CachedNetworkImage`, whose `flutter_cache_manager`
  // backend needs `path_provider` (unavailable under `flutter test`). The
  // multi-image structure is covered by `product_image_gallery_widget_test`.
  testWidgets('product image gallery placeholder matches its golden',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(images: [], heroTag: 'golden-hero'),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(ProductImageGallery),
      matchesGoldenFile('../../../../goldens/product_gallery.png'),
    );
  });
}
