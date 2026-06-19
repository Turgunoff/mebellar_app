import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/models/product_model.dart';

Map<String, dynamic> _baseJson({
  String? arModelUrl,
  String? arUsdzUrl,
  String arStatus = 'approved',
}) {
  final json = <String, dynamic>{
    'id': 'p1',
    'category_id': 'cat-1',
    'name': 'Krovat',
    'price': 1000000,
    'images': const <String>[],
    'stock': 5,
    'created_at': '2026-01-01T00:00:00.000Z',
    'ar_status': arStatus,
  };
  if (arModelUrl != null) json['ar_model_url'] = arModelUrl;
  if (arUsdzUrl != null) json['ar_usdz_url'] = arUsdzUrl;
  return json;
}

void main() {
  group('ProductModel AR formats', () {
    test('parses ar_usdz_url into usdzUrl', () {
      final p = ProductModel.fromJson(
        _baseJson(
          arModelUrl: 'https://cdn/m.glb',
          arUsdzUrl: 'https://cdn/m.usdz',
        ),
      );
      expect(p.arModelUrl, 'https://cdn/m.glb');
      expect(p.usdzUrl, 'https://cdn/m.usdz');
    });

    test('usdzUrl is null when ar_usdz_url is absent (glb-only)', () {
      final p = ProductModel.fromJson(_baseJson(arModelUrl: 'https://cdn/m.glb'));
      expect(p.arModelUrl, 'https://cdn/m.glb');
      expect(p.usdzUrl, isNull);
    });

    test('usdzUrl is null when ar_usdz_url is blank', () {
      final p = ProductModel.fromJson(
        _baseJson(arModelUrl: 'https://cdn/m.glb', arUsdzUrl: '   '),
      );
      expect(p.usdzUrl, isNull);
    });

    test('toJson emits ar_usdz_url only when set', () {
      final withUsdz = ProductModel.fromJson(
        _baseJson(arModelUrl: 'https://cdn/m.glb', arUsdzUrl: 'https://cdn/m.usdz'),
      ).toJson();
      expect(withUsdz['ar_usdz_url'], 'https://cdn/m.usdz');

      final withoutUsdz =
          ProductModel.fromJson(_baseJson(arModelUrl: 'https://cdn/m.glb')).toJson();
      expect(withoutUsdz.containsKey('ar_usdz_url'), isFalse);
    });

    test('fromJson(toJson(x)) round-trips both AR URLs', () {
      final original = ProductModel.fromJson(
        _baseJson(arModelUrl: 'https://cdn/m.glb', arUsdzUrl: 'https://cdn/m.usdz'),
      );
      final roundTripped = ProductModel.fromJson(original.toJson());
      expect(roundTripped.arModelUrl, original.arModelUrl);
      expect(roundTripped.usdzUrl, original.usdzUrl);
    });
  });
}
