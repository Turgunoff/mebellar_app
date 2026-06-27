import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:woody_app/core/di/service_locator.dart';
import 'package:woody_app/seller/features/products/ar_section.dart';
import 'package:woody_app/seller/features/products/data/ar_scan_repository.dart';
import 'package:woody_app/seller/features/products/data/ar_token_repository.dart';
import 'package:woody_app/shared/models/ar_part.dart';
import 'package:woody_app/shared/models/multilingual_text.dart';
import 'package:woody_app/shared/models/seller_product.dart';

class _MockArScanRepo extends Mock implements ArScanRepository {}

class _MockArTokenRepo extends Mock implements ArTokenRepository {}

SellerProduct _approvedProduct() => SellerProduct(
      id: 'p1',
      name: const MultilingualText(uz: 'Divan', ru: 'Диван', en: 'Sofa'),
      description: const MultilingualText(),
      categorySlug: 'cat',
      price: 100,
      sku: 'SKU',
      images: const [],
      attributes: const {},
      // Real dimensions → the single derived component isComplete, so the
      // "request" button (the previously-crashing FilledButton) renders.
      widthCm: 160,
      heightCm: 80,
      lengthCm: 210,
      status: SellerProductStatus.approved,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late _MockArScanRepo scanRepo;
  late _MockArTokenRepo tokenRepo;

  setUp(() {
    scanRepo = _MockArScanRepo();
    tokenRepo = _MockArTokenRepo();
    when(() => scanRepo.fetchArParts(any())).thenAnswer((_) async => <ArPart>[]);
    when(() => tokenRepo.balance()).thenAnswer(
      (_) async => const ArTokenBalance(arCredits: 5, packages: []),
    );
    if (sl.isRegistered<ArScanRepository>()) sl.unregister<ArScanRepository>();
    if (sl.isRegistered<ArTokenRepository>()) sl.unregister<ArTokenRepository>();
    sl.registerSingleton<ArScanRepository>(scanRepo);
    sl.registerSingleton<ArTokenRepository>(tokenRepo);
  });

  tearDown(() {
    sl.unregister<ArScanRepository>();
    sl.unregister<ArTokenRepository>();
  });

  testWidgets(
    'renders the request state without an infinite-width layout exception',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // A bounded width that still forces the trailing button to lay out
            // as a non-flex Row child — the exact condition that used to throw
            // "BoxConstraints forces an infinite width" with FilledButton.icon.
            body: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: SellerArSection(product: _approvedProduct(), schema: const []),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No layout/render exception was thrown during the build.
      expect(tester.takeException(), isNull);
      // The per-part request button rendered.
      expect(find.byType(FilledButton), findsWidgets);
      expect(find.text('So‘rov yuborish'), findsOneWidget);
    },
  );
}
