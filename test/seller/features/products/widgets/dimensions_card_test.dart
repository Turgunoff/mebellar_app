import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/seller/features/products/widgets/product_form/dimensions_card.dart';
import 'package:woody_app/shared/models/attribute_definition.dart';

AttributeDefinition _dim(String key, String labelUz, {String unit = 'sm'}) {
  return AttributeDefinition(
    id: 'def-$key',
    categoryId: 'cat-1',
    subcategoryId: null,
    key: key,
    labelUz: labelUz,
    labelRu: labelUz,
    dataType: AttributeDataType.number,
    unit: unit,
    isRequired: false,
    sortOrder: 0,
  );
}

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC27A5F)),
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('isDimensionAttribute recognises sm number with em-dash label', (
    tester,
  ) async {
    expect(
      DimensionsCard.isDimensionAttribute(
        _dim('bed_length_cm', 'Krovat — uzunligi'),
      ),
      isTrue,
    );
    // Wrong unit / no dash / non-number → not a dimension.
    expect(
      DimensionsCard.isDimensionAttribute(
        _dim('warranty', 'Kafolat', unit: 'oy'),
      ),
      isFalse,
    );
    expect(
      DimensionsCard.isDimensionAttribute(
        AttributeDefinition(
          id: 'x',
          categoryId: 'c',
          subcategoryId: null,
          key: 'mattress_size',
          labelUz: 'Matras',
          labelRu: 'Matras',
          dataType: AttributeDataType.text,
          unit: null,
          isRequired: false,
          sortOrder: 0,
        ),
      ),
      isFalse,
    );
  });

  testWidgets('groups dimensions by piece and reports edits by key', (
    tester,
  ) async {
    final changes = <String, dynamic>{};
    await tester.pumpWidget(
      _host(
        DimensionsCard(
          definitions: [
            _dim('bed_length_cm', 'Krovat — uzunligi'),
            _dim('bed_width_cm', 'Krovat — kengligi'),
            _dim('wardrobe_width_cm', 'Shkaf — kengligi'),
          ],
          values: const {'bed_length_cm': 214},
          locale: 'uz',
          onChanged: (k, v) => changes[k] = v,
        ),
      ),
    );

    // Two piece headers (Krovat, Shkaf) + measure labels appear.
    expect(find.text('Krovat'), findsOneWidget);
    expect(find.text('Shkaf'), findsOneWidget);
    expect(find.text('uzunligi'), findsOneWidget);

    // Pre-filled value shows.
    expect(find.text('214'), findsOneWidget);

    // Editing a field reports the change keyed by the attribute key.
    await tester.enterText(find.byType(TextField).last, '220');
    expect(changes['wardrobe_width_cm'], 220);
  });
}
